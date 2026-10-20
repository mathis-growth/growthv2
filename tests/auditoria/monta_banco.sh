#!/bin/bash
# monta o banco "full" do zero: stubs do Supabase + todas as migrações em ordem
DB=${1:-full}
dropdb -p 55432 --if-exists $DB; createdb -p 55432 $DB
sed "s/alter database \"full\"/alter database \"$DB\"/" /var/lib/postgresql/full/stub.sql > /tmp/stub_$DB.sql
psql -p 55432 -d $DB -q -v ON_ERROR_STOP=1 -f /tmp/stub_$DB.sql
n=0
for f in /var/lib/postgresql/full/mig/*.sql; do
  out=$(psql -p 55432 -d $DB -q -v ON_ERROR_STOP=1 -1 -f $f 2>&1 | grep -E "ERROR" | head -2)
  if [ -n "$out" ]; then echo "FALHA $(basename $f): $out"; n=$((n+1)); fi
done
echo "falhas: $n"
