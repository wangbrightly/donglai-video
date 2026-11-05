package net.donglai.video;
final class Resume {
 static int position(int saved,int duration){return saved<=0 || (duration>0 && saved>=Math.max(0,duration-2000))?0:saved;}
}
