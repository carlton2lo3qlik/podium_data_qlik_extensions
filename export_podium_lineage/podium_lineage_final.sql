---
--- please update the WHERE clause with parent_entity.sname = 'brad_lin_test_2' for the ENTITY lineage report.
---

WITH recursive podium_lineage_children AS 
( 
           SELECT     parent_source.sname               AS parent_source_name, 
                      parent_entity.sname               AS parent_entity_name, 
                      parent_field.nid                  AS podium_parent_field_key, 
                      parent_field.sname                AS parent_field_name, 
                      field_relation.relation_info AS calculation, 
                      child_source.sname                AS child_source_name, 
                      child_entity.sname                AS child_entity_name, 
                      child_field.nid                   AS podium_child_field_key, 
                      child_field.sname                 AS child_field_name 
           FROM       podium_core.pd_field_pc_rel field_relation
           INNER JOIN podium_core.pd_field parent_field 
           ON         field_relation.parent_field_nid=parent_field.nid
           INNER JOIN podium_core.pd_field child_field 
           ON         field_relation.child_field_nid=child_field.nid
           INNER JOIN podium_core.pd_entity parent_entity 
           ON         parent_field.entity_nid=parent_entity.nid
           INNER JOIN podium_core.pd_source parent_source 
           ON         parent_entity.source_nid=parent_source.nid
           INNER JOIN podium_core.pd_entity child_entity 
           ON         child_field.entity_nid=child_entity.nid
           INNER JOIN podium_core.pd_source child_source 
           ON         child_entity.source_nid=child_source.nid
                      --MODIFY THIS WHERE CLAUSE 1 OF 2
                      --You can use a single table name 
                      --Or an IN clause with many talbes, 
                      --Or join to a table list with a sub select 
           WHERE      parent_entity.sname = 'brad_lin_test_2' 
                      -- 
                      -- 
                      -- 
           AND        field_relation.relation_info != '' 
           UNION 
           SELECT     parent_source.sname               AS parent_source_name, 
                      parent_entity.sname               AS parent_entity_name, 
                      parent_field.nid                  AS podium_parent_field_key, 
                      parent_field.sname                AS parent_field_name, 
                      field_relation.relation_info AS calculation, 
                      child_source.sname                AS child_source_name, 
                      child_entity.sname                AS child_entity_name, 
                      child_field.nid                   AS podium_child_field_key, 
                      child_field.sname                 AS child_field_name 
           FROM       podium_core.pd_field_pc_rel field_relation
           INNER JOIN podium_core.pd_field parent_field 
           ON         field_relation.parent_field_nid=parent_field.nid
           INNER JOIN podium_core.pd_field child_field 
           ON         field_relation.child_field_nid=child_field.nid 
           INNER JOIN podium_core.pd_entity parent_entity 
           ON         parent_field.entity_nid=parent_entity.nid
           INNER JOIN podium_core.pd_source parent_source 
           ON         parent_entity.source_nid=parent_source.nid
           INNER JOIN podium_core.pd_entity child_entity 
           ON         child_field.entity_nid=child_entity.nid
           INNER JOIN podium_core.pd_source child_source 
           ON         child_entity.source_nid=child_source.nid
           INNER JOIN podium_lineage_children e 
           ON         upper(e.child_entity_name) = upper(parent_entity.sname) 
           AND        field_relation.relation_info != '' ), podium_lineage_parents AS 
( 
           SELECT     parent_source.sname               AS parent_source_name, 
                      parent_entity.sname               AS parent_entity_name, 
                      parent_field.nid                  AS podium_parent_field_key, 
                      parent_field.sname                AS parent_field_name, 
                      field_relation.relation_info AS calculation, 
                      child_source.sname                AS child_source_name, 
                      child_entity.sname                AS child_entity_name, 
                      child_field.nid                   AS podium_child_field_key, 
                      child_field.sname                 AS child_field_name 
           FROM       podium_core.pd_field_pc_rel field_relation
           INNER JOIN podium_core.pd_field parent_field 
           ON         field_relation.parent_field_nid=parent_field.nid
           INNER JOIN podium_core.pd_field child_field 
           ON         field_relation.child_field_nid=child_field.nid
           INNER JOIN podium_core.pd_entity parent_entity 
           ON         parent_field.entity_nid=parent_entity.nid
           INNER JOIN podium_core.pd_source parent_source 
           ON         parent_entity.source_nid=parent_source.nid
           INNER JOIN podium_core.pd_entity child_entity 
           ON         child_field.entity_nid=child_entity.nid
           INNER JOIN podium_core.pd_source child_source 
           ON         child_entity.source_nid=child_source.nid
                      --MODIFY THIS WHERE CLAUSE 2 OF 2
                      --You can use a single table name 
                      --Or an IN clause with many talbes, 
                      --Or join to a table list with a sub select 
           WHERE      child_entity.sname = 'brad_lin_test_2'
                      -- 
                      -- 
                      -- 
           AND        field_relation.relation_info != '' 
           UNION 
           SELECT     parent_source.sname               AS parent_source_name, 
                      parent_entity.sname               AS parent_entity_name, 
                      parent_field.nid                  AS podium_parent_field_key, 
                      parent_field.sname                AS parent_field_name, 
                      field_relation.relation_info AS calculation, 
                      child_source.sname                AS child_source_name, 
                      child_entity.sname                AS child_entity_name, 
                      child_field.nid                   AS podium_child_field_key, 
                      child_field.sname                 AS child_field_name 
           FROM       podium_core.pd_field_pc_rel field_relation
           INNER JOIN podium_core.pd_field parent_field 
           ON         field_relation.parent_field_nid=parent_field.nid
           INNER JOIN podium_core.pd_field child_field 
           ON         field_relation.child_field_nid=child_field.nid
           INNER JOIN podium_core.pd_entity parent_entity 
           ON         parent_field.entity_nid=parent_entity.nid
           INNER JOIN podium_core.pd_source parent_source 
           ON         parent_entity.source_nid=parent_source.nid
           INNER JOIN podium_core.pd_entity child_entity 
           ON         child_field.entity_nid=child_entity.nid
           INNER JOIN podium_core.pd_source child_source 
           ON         child_entity.source_nid=child_source.nid
           INNER JOIN podium_lineage_parents f 
           ON         upper(f.parent_entity_name) = upper(child_entity.sname) 
           AND        field_relation.relation_info != '' ) 
SELECT * 
FROM   podium_lineage_parents 
UNION 
SELECT   * 
FROM     podium_lineage_children 
ORDER BY podium_parent_field_key;