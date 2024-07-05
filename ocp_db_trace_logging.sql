/* undo
drop table ocp_db_trace_logging;
drop sequence ocp_dtl_seq1;
*/

create sequence ocp_dtl_seq1 start with 1 increment by 1 cache 20;
 
create table ocp_db_trace_logging (
  id         number default ocp_dtl_seq1.nextval not null
 ,cmp_id     number      
 ,cmpcode    varchar2(4) 
 ,date_time  date default sysdate not null
 ,x_request_id varchar2(100)
 ,requester_id varchar2(100)
 ,trace_data clob        not null
 ,constraint ocp_dtl_pk primary key (id)
 ,constraint ocp_dtl_ck1 check (cmpcode in ('TRX', 'LEV', 'PUB', 'KAN', 'PATS'))
 ,constraint ocp_dtl_ck2 check (trace_data is json)
)
lob (trace_data)
  store as securefile (
    cache
  )
;   
  
create index ocp_dtl_idx on ocp_db_trace_logging (cmp_id, cmpcode);  
create index ocp_dtl_idx2 on ocp_db_trace_logging (x_request_id); 