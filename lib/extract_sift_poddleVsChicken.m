% Extract SIFT features for poddle vs. fried chicken image set
% Require vlfeat-0.9.20
% Adapted codes from http://www.vlfeat.org/applications/caltech-101-code.html

function extract_sift_poddleVsChicken()

conf.calDir = './' ; % calculating directory
conf.dataDir = './images/' ; % data (image) directory 
conf.outDir = './output2/'; % output directory
conf.numWords = 5000 ; % vocabulary size
conf.numSpatialX = 1 ; % spatial histogram configuration
conf.numSpatialY = 1 ;
conf.quantizer = 'kdtree' ; % search structure

conf.prefix = 'sift_pf' ;
conf.randSeed = 1 ;

conf.descrPath = fullfile(conf.outDir,[conf.prefix '-descr.mat']);
conf.vocabPath = fullfile(conf.outDir, [conf.prefix '-vocab.mat']);
conf.histPath = fullfile(conf.outDir, [conf.prefix '-hists.mat']) ;
conf.modelPath = fullfile(conf.outDir, [conf.prefix '-model.mat']) ;
conf.resultPath = fullfile(conf.outDir, [conf.prefix '-result']) ;


conf.descrPath = fullfile(conf.outDir, [conf.prefix '-selectedDescr.mat']);
conf.framePath = fullfile(conf.outDir, [conf.prefix '-selectedFrame.mat']);

randn('state',conf.randSeed) ;
rand('state',conf.randSeed) ;
vl_twister('state',conf.randSeed) ;

model.numSpatialX = conf.numSpatialX ;
model.numSpatialY = conf.numSpatialY ;
model.quantizer = conf.quantizer ;
model.vocab = [] ;

% --------------------------------------------------------------------
%                                                     Train vocabulary
% --------------------------------------------------------------------

file = fopen('train_img_names.csv');
imagenames = textscan(file, '%s %*[^\n]');
fclose(file);
imagenames = imagenames{:};
imagenames = imagenames(2:end);
[nfiles, s] = size(imagenames);

if ~exist(conf.vocabPath)

  % Get some SIFT descriptors to train the dictionary
  descrs = {} ;
  frame = {};
  img_names = {};
  %for ii = 1:length(selTrainFeats)
  parfor ii = 1:nfiles
  %for ii = 1:nfiles
    fprintf('Processing dictionary %s (%.2f %%)\n', imagenames{ii}, 100 * ii /nfiles) ;
    currentFileName = imagenames{ii};
    imm = imread(currentFileName);
    if length(size(imm)) == 3
        im = single(rgb2gray(imm));
    else
        im = single(imm);
    end
    if size(im,1) > 480
        im = imresize(im, [480 NaN]);
        fprintf('\tResize.\n');
    end
    [frame{ii}, descrs{ii}] = vl_sift(im, 'PeakThresh', 10,'EdgeThresh',10);
    [m1, m2] = size(frame{ii});
    img_names{ii} = repmat(ii, m2, 1);
  end
  [descrsSelected, sel_ind] = vl_colsubset(cat(2, descrs{:}), 50000); % subsample features descriptor if having limited computational resource
  descrsSelected = single(descrsSelected);
  save(conf.descrPath, 'descrsSelected'); 
  % save the corresponding frames for feature visualization
  framesSelected = horzcat(frame{:});
  framesSelected = framesSelected(:,sel_ind).';
  save(conf.framePath, 'framesSelected');
  % save the correspond image index for feature visualization
  imgSelected = cat(1, img_names{:});
  imgSelected = imgSelected(sel_ind, :);
  
  csvwrite('./output2/frameSelected.csv', framesSelected);
  csvwrite('./output2/imgSelected.csv', imgSelected);
  % Quantize the descriptors to get the visual words
  [vocab, assign] = vl_kmeans(descrsSelected, conf.numWords, 'verbose', 'algorithm', 'elkan', 'MaxNumIterations', 100) ;
  save(conf.vocabPath, 'vocab');
  
  assign_tr = assign.';
  csvwrite('./output/sift_feature_assign.csv', assign_tr);
  
else
  load(conf.vocabPath) ;
end

model.vocab = vocab ;

if strcmp(model.quantizer, 'kdtree')
  model.kdtree = vl_kdtreebuild(vocab) ;
end

% --------------------------------------------------------------------
%                                           Compute spatial histograms
% --------------------------------------------------------------------

imagefilesAll = dir(strcat(conf.dataDir,'*.jpg'));      
nfilesALL = length(imagefilesAll);

if ~exist(conf.histPath)
  fprintf('Compute spatial histogram\n');
  hists = {} ;
  parfor ii = 1:nfilesALL
  % for ii = 1:length(images)
    fprintf('Processing dictionary %s (%.2f %%)\n', imagefilesAll(ii).name, 100 * ii /nfilesALL) ;
    %im = imread(fullfile(conf.calDir, images{ii})) ;
    currentFileName = imagefilesAll(ii).name;
    imm = imread(currentFileName);
    hists{ii} = getImageDescriptor(model, imm);
  end

  hists = cat(2, hists{:}) ;
  save(conf.histPath, 'hists');
  % Save the sparse matrix for the use of R
  [row,col,v] = find(hists);
  hists_sparse = [row, col, v];
  csvwrite('./output2/hists_sparse_full.csv',hists_sparse);

else
  load(conf.histPath);
end


% -------------------------------------------------------------------------
function im = standarizeImage(im)
% -------------------------------------------------------------------------

im = im2single(im) ;
if size(im,1) > 480, im = imresize(im, [480 NaN]) ; end

% -------------------------------------------------------------------------
function hist = getImageDescriptor(model, imm)
% -------------------------------------------------------------------------
if length(size(imm)) == 3
        im = single(rgb2gray(imm));
else
    im = single(imm);
end

if size(im,1) > 480
    im = imresize(im, [480 NaN]);
    fprintf('\tResize.\n');
end
%im = standarizeImage(im) ;
width = size(im,2) ;
height = size(im,1) ;
numWords = size(model.vocab, 2) ;

% get sift features
[frames, descrs] = vl_sift(im) ;

% quantize local descriptors into visual words
switch model.quantizer
  case 'vq'
    [drop, binsa] = min(vl_alldist(model.vocab, single(descrs)), [], 1) ;
  case 'kdtree'
    binsa = double(vl_kdtreequery(model.kdtree, model.vocab, ...
                                  single(descrs), ...
                                  'MaxComparisons', 50)) ;
end

for i = 1:length(model.numSpatialX)
  binsx = vl_binsearch(linspace(1,width,model.numSpatialX(i)+1), frames(1,:)) ;
  binsy = vl_binsearch(linspace(1,height,model.numSpatialY(i)+1), frames(2,:)) ;

  % combined quantization
  bins = sub2ind([model.numSpatialY(i), model.numSpatialX(i), numWords], ...
                 binsy,binsx,binsa) ;
  hist = zeros(model.numSpatialY(i) * model.numSpatialX(i) * numWords, 1) ;
  hist = vl_binsum(hist, ones(size(bins)), bins) ;
  hists{i} = single(hist / sum(hist)) ;
end
hist = cat(1,hists{:}) ;
hist = hist / sum(hist) ;

