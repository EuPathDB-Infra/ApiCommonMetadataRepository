DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d "$1" ] ; then
  echo "Usage: $0 <studies_dir>"
  exit 1
fi
for f in "$1"/*txt ; do
  echo "$(basename $f)	$( head -n1 $f )" ;
done \
  | perl -nE '
  chomp;
  my ($f, @xs) = split "\t";
  say "${f}::$_" for grep {$_ ne "name" && $_ ne "description" && $_ ne "samplemtoverride" && $_ ne "sourcemtoverride" } @xs
' | sort
