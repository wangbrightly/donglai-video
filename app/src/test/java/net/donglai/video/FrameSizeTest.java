package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class FrameSizeTest {
 @Test public void fitsInsideSquareWithoutChangingAspect(){
  assertArrayEquals(new int[]{320,180},FrameSize.fit(1920,1080,320));
  assertArrayEquals(new int[]{180,320},FrameSize.fit(1080,1920,320));
  assertArrayEquals(new int[]{320,320},FrameSize.fit(100,100,320));
  assertArrayEquals(new int[]{320,180},FrameSize.fit(0,0,320));
 }
}
