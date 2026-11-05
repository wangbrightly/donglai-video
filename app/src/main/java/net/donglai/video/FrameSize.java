package net.donglai.video;
final class FrameSize {
 static int[] fit(int w,int h,int max){
  if(w<=0||h<=0){w=16;h=9;}
  double scale=(double)max/Math.max(w,h);
  return new int[]{Math.max(1,(int)Math.round(w*scale)),Math.max(1,(int)Math.round(h*scale))};
 }
}
