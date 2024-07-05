create or replace type error_type force authid current_user as object (
  err_code varchar2(10)
, err_msg  varchar2(1000)
);
/