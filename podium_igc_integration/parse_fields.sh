set -x
let linecount=`wc -l field_terms_out.txt`
let tailcount=linecount-3
let headcount=linecount-4

echo $linecount
echo $tailcount

tail -$tailcount field_terms_out.txt | head -$headcount >f_tmp
IFS='
'
for i in `cat f_tmp`
do
echo $i
term=`echo $i | awk -F"|" '{gsub(/ /,"",$0);print $1}'`
desc=`echo $i | awk -F"|" '{gsub(/ /," ",$0); print $2}'`
echo $desc
echo -n '{
 "_type" : "term",
 "short_description" : ' > jj
echo "\"$desc \"," >> jj
echo -n ' "status" : "ACCEPTED",
 "parent_category" : "6662c0f2.ee6a64fe.fql6218hp.r6h8i7i.dfp9i3.7nprkaf1448qtlt4lbha1",
 "name" : ' >> jj
echo "\"${term}\"" >> jj
echo } >> jj

curl -v --insecure -H "Content-Type:application/json" -H "Accept-Encoding:identity" --data "@jj" -u isadmin:podium "https://ludwig.podiumdata.com:9445/ibm/iis/igc-rest/v1/assets"
sleep 5


 done
