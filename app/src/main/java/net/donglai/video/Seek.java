package net.donglai.video;
final class Seek {
 static int target(int position,int offset,int duration){return (int)Math.max(0,Math.min((long)Math.max(0,duration),(long)position+offset));}
}
