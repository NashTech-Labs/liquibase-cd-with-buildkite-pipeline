--liquibase formatted sql
				
--changeset sachinvd:1
create table test3 (  
    id int primary key,
    name varchar(255)  
);  
--rollback drop table test1; 

--changeset sachinvd:2 runOnChange:true
insert into test3 (id, "name") values (09, 'name 1');

--changeset sachinvd:4 runOnChange:true
insert into test3 (id,  "name") values (20, 'name 2');  

insert into test3 (id, "name") values (10, 'name 1');

--changeset sachinvd:4 runOnChange:true
insert into test3 (id,  "name") values (21, 'name 2');  
