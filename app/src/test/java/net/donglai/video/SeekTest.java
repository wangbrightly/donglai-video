package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class SeekTest {
 @Test public void skipsWithinVideoBounds(){
  assertEquals(0,Seek.target(5000,-15000,100000));
  assertEquals(35000,Seek.target(20000,15000,100000));
  assertEquals(100000,Seek.target(95000,15000,100000));
 }
}
