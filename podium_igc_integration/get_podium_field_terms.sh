psql -U postgres << EOF
\c podium_md_cs;
select * from (
select distinct 
f.business_name, trim(e.sname) ||'.' || trim(f.sname) || ' - ' || regexp_replace(f.business_desc, E'[\\n\\r]+', ' ', 'g' )
from podium_core.pd_field f join podium_core.pd_entity e on f.entity_nid = e.nid
where trim(f.business_name) is not null and f.business_desc is not null) foo
where trim(business_name) <> '';

EOF
