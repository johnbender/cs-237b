set -e

name="$1"
file="$1.tex"

build(){
  echo $1
  latex --file-line-error --halt-on-error --output-format=pdf $1 # \
}

pushd essays

# build once by default
build "$file"

cat "$file" > "/tmp/$file"

# watch for alterations
while true; do
  # if there's a difference
  if ! diff "/tmp/$file" "$file" > /dev/null; then
      build "$file"
      # bibtex "$name.aux"
      cat "$file" > "/tmp/$file"
  else
    sleep 1
  fi
done

popd -n
