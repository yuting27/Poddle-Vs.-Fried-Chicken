### Visualize SIFT features
frames <- read.csv("sift_frame_pf.csv", header=F)
colnames(frames) <- c("X", "Y", "width", "theta")
assign <- read.csv("sift_feature_assign.csv", header=F)
frames$assignment <- unlist(assign)
img_names <- read.csv("train_img_names.csv", header=T)
imgInd <- read.csv("imgSelected.csv", header=F)
frames$img <- unlist(img_names)[unlist(imgInd)]

draw_feature <- function(ind_var, magnif = 3){
  
  # ind_var = index of feature for visualization
  # magnif = the magnification factor for visualizing the keypoints
  
  library(EBImage)
  ind_f <- which(frames$assignment == ind_var)
  ind_f <- ind_f[-1]
  ff <- frames[ind_f, ]
  if(!is.null(ff)){
    if(nrow(ff) > 0){
      img_agg <- NULL
      img_agg_c <- NULL
      d <- 10 # patch size
      for(i in 1:nrow(ff)){
        s <- ff[i,]
        cat("i=", i, ":", s$img, "\n")
        try_tmp <- try(img <- readImage(files=paste0("./images/", s$img)), silent=TRUE)
        if(class(try_tmp) == "try-error"){
          cat("skip", i, "\n")
          next
        }
        
        d_y <- ncol(img)
        d_x <- nrow(img)
        x <- as.numeric(s[1])
        y <- as.numeric(s[2])
        w0 <- as.numeric(s[3])*2
        w <- w0* magnif
        if(length(dim(img)) == 3){
          img <- drawCircle(img, x, y, w0 , col="red")
          img_s <- img[max(0,round(x-w)):min(d_x,round(x+w)),max(0,round(y-w)):min(d_y,round(y+w)),]
        } else{ #for grayscale image
          img <- drawCircle(img, x, y, w0 , col="red")
          img_s <- img[max(0,round(x-w)):min(d_x,round(x+w)),max(0,round(y-w)):min(d_y,round(y+w))]
        }
        img_s <- resize(img_s, d, d)
        img_agg <- EBImage::combine(img_agg, img_s)
      }
      jpeg(paste0("varFeature_", ind_var, ".jpg"))
      display(resize(img_agg, 256, 256), method = "raster", all = TRUE)
      dev.off()
    }
  }
}

# Example
draw_feature(1)
