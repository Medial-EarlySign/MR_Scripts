draw_dists <- function(labsig) {
  
  hfile = paste("Lab/",labsig,"/hists.csv",sep="")
  dfile = paste("Lab/",labsig,"/dists.csv",sep="")
  
  h<-read.csv(hfile,h=F,sep=",")
  d<-read.csv(dfile,h=F,sep=",")
 
  sig = h[1,1]
  types_to_draw = c("Males","Females")
  for (t in types_to_draw) {
    print(sprintf("sig %s , type %s\n",sig,t))
    ht<-h[h$V2==t,]
    print(dim(ht))
    y<-ht[,6]/sum(ht[,6])
    dd<-(max(ht[,5])-min(ht[,5]))/1000;
    x<-seq(min(ht[,5]),max(ht[,5]),dd);
    print("x1")
    print(x[1])
    print("x-last")
    print(x[length(x)])
    fact = (ht[2,5]-ht[1,5])/dd;
    print("fact")
    print(fact)
    #x<-ht[,5]
    plot(ht[,5],y,xlab=sig,ylab="prob");
    print(d)
#    p<-d[d$V2==t && d$V3=='Normal',]
    p<-d[d$V2==t & d$V3=="Normal",]
    print(p)
    a<-dnorm(x,p$V5,p$V6)
    lines(x,fact*p$V4*(a/sum(a)),col="blue")
    
    p<-d[d$V2==t & d$V3=="LogNormal",]
    print(p)
    a<-dlnorm(x,p$V5,p$V6)
    lines(x,fact*p$V4*(a/sum(a)),col="red")  
    
    p<-d[d$V2==t & d$V3=="Skewed",]
    print(p)
    a<-dsn(x,p$V5,p$V6,p$V7)
    lines(x,fact*p$V4*(a/sum(a)),col="green")  
    
    title(sprintf("%s - %s",sig,t))
    grid()
    legend("topright",c("Normal","LogNormal","Skewed"),lty=c(1,1,1), lwd=c(2,2,2), col=c("blue","red","green"))
    
    out = paste("Lab/",labsig,"/",labsig,"_fit_",t,".jpeg",sep="")
    dev.print(jpeg,out,width=945)
  }
}

draw_ages<-function (labsig,l,h)
{
  w = 1280;
  afile<-paste("Lab/",labsig,"/ages.csv",sep="")
  a<-read.csv(afile,h=F,sep=",")  
  a
  sig = a[1,1]
  method = a[1,3]
  types_to_draw = c("Males","Females")
  
  # plot males vs. females
  males<-a[a$V2=="Males",]
  females<-a[a$V2=="Females",]  
  mn<-min(min(males[,11],females[,11]))
  mx<-max(max(males[,11],females[,11]))
  plot(males[,4],males[,11],type="l",xlab="Age",ylab=sig,ylim=c(mn,mx))
  title(sprintf("%s - males/females",sig))
  lines(males[,4],males[,11],lwd=2,col="blue")
  lines(females[,4],females[,11],lwd=2,col="red")
  grid()
  out=paste("Lab/",labsig,"/",labsig,"_norm_MF.jpeg",sep="")
  dev.print(jpeg,out,width=w);
  # males , females , with dist bands
  i<-1
  for (t in types_to_draw) { 
    at<-a[a$V2==t,]
    limy=c(min(at[,8]),max(at[,14]))
    plot(at[,4],at[,11],type="l",col="black",xlab="Age",ylab=sig,ylim=limy,lwd=2)
    polygon(c(at[,4],rev(at[,4])),c(at[,8],rev(at[,14])),col="grey55")
    polygon(c(at[,4],rev(at[,4])),c(at[,9],rev(at[,13])),col="grey65")    
    polygon(c(at[,4],rev(at[,4])),c(at[,10],rev(at[,12])),col="grey75")
    lines(at[,4],at[,10],col="grey75")
    lines(at[,4],at[,12],col="grey75")
    lines(at[,4],at[,9],col="grey65")
    lines(at[,4],at[,13],col="grey65")
    lines(at[,4],at[,8],col="grey55")
    lines(at[,4],at[,14],col="grey55")
    lines(at[,4],at[,11],lwd=3)
    title(sprintf("%s - %s",sig,t))
    grid()

    if (l[i]>0) {
      abline(h=l[i],lty=2,col="grey25",lwd=2)
      abline(h=h[i],lty=2,col="grey25",lwd=2)
    }
    i<-length(l)
    out=paste("Lab/",labsig,"/",labsig,"_norm_",t,".jpeg",sep="")
    dev.print(jpeg,out,width=w);
  }
  
  # plotting how many are below,above thresholds
  mx<-0;
  mx<-max(mx,a[,15]);
  mx<-max(mx,a[,17]);
  
  plot(males[,4],males[,15],type="l",col="blue",xlab="Age",ylab="below/above thresholds",ylim=c(0,mx))
  lines(males[,4],males[,21],col="blue",lty=2)
  lines(males[,4],males[,16],col="blue",lty=1)
  lines(males[,4],males[,20],col="blue",lty=2)
  lines(males[,4],males[,17],col="blue",lty=1)
  lines(males[,4],males[,19],col="blue",lty=2)
  
  lines(females[,4],females[,15],col="red",lty=1)
  lines(females[,4],females[,21],col="red",lty=2)
  lines(females[,4],females[,16],col="red",lty=1)
  lines(females[,4],females[,20],col="red",lty=2)
  lines(females[,4],females[,17],col="red",lty=1)
  lines(females[,4],females[,19],col="red",lty=2)
  
  title(sprintf("%s - percent above/below thresholds",sig))
  grid()
}

get_depended_counts<-function(feat,b0,b1,step)
{
  x = seq(b0,b1,step)
  print(length(x))
  a<-matrix(0,length(x)-1,6)
  for (i in 1:length(x)-1) {
    a[i,1] = x[i]
    a[i,2] = x[i+1]
    a[i,3] = length(feat[feat$V5>=x[i] & feat$V5<x[i+1] & feat$V4==0,4])
    a[i,4] = length(feat[feat$V5>=x[i] & feat$V5<x[i+1] & feat$V4==1,4])
    a[i,5] = length(feat[feat$V5>=x[i] & feat$V5<x[i+1],4])
    a[i,6] = a[i,4]/(a[i,5])
  }
  
  print(a)
}


