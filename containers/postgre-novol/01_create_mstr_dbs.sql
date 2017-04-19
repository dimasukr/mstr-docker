create role mstr_meta with login CREATEDB password 'g1n2s3s4';
grant mstr_meta to postgres;
create database mstr_meta owner mstr_meta;

create role mstr_hist with login CREATEDB password 'g1n2s3s4';
grant mstr_hist to postgres;
alter role mstr_hist set STANDARD_CONFORMING_STRINGS to off;
create database mstr_hist owner mstr_hist;
