build(){
  latex --file-line-error --halt-on-error --output-format=pdf --output-dir=../output $1
}

mkdir -p output
pushd tex
build $@
popd -n
