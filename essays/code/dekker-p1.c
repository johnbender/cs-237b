bool p1() {
  flag1 = 1;
  if(flag0 == 1){
    return false;
  }
  // critical
  flag1 = 0;
  return true;
}
