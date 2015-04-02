bool p0() {
  flag0 = 1;
  if(flag1 == 1){
    return false;
  }
  // critical
  flag0 = 0;
  return true;
}
