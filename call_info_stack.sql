create or replace type call_info_stack force authid current_user as object
(
------------------------------------------------------
-- attributes
------------------------------------------------------
  trace_on     integer, /* 1 = on / 0 = off */
  x_request_id varchar2(100),
  requester_id varchar2(100),
  stack_list   code_trace_list,
------------------------------------------------------
-- constructors
------------------------------------------------------
-- non-args
  constructor function call_info_stack(self in out nocopy call_info_stack) return self as result,
------------------------------------------------------
-- members
------------------------------------------------------
  member procedure add_info
  (
    self   in out nocopy call_info_stack
   ,p_data in varchar2
  ),

  member procedure add_call_stack
  (
    self      in out nocopy call_info_stack
   ,p_comment in varchar2
  ),

  member procedure add_stack
  (
    self    in out nocopy call_info_stack
   ,p_stack in call_info_stack
  ),

  member function is_empty(self in out nocopy call_info_stack) return boolean,

  member function is_not_empty(self in out nocopy call_info_stack) return boolean,

  member function to_json return clob
)
/
create or replace type body call_info_stack as

  -- constructor
  constructor function call_info_stack(self in out nocopy call_info_stack) return self as result is
  begin
    self.stack_list := new code_trace_list();

    select count(*)
      into self.trace_on
      from b2b_instellingen t
     where t.feature_naam = 'database trace'
       and t.ind_feature_aan = 'J';

    if (self.trace_on = 1 and owa.num_cgi_vars is not null)
    then
      self.x_request_id := substr(owa_util.get_cgi_env('X-request-id'), 1, 100);
      self.requester_id := substr(owa_util.get_cgi_env('requester-id'), 1, 100);
    end if;
    return;
  end;

  member procedure add_info
  (
    self   in out nocopy call_info_stack
   ,p_data in varchar2
  ) is
    l_code_trace code_trace;
  begin
    if (self.trace_on = 1 and p_data is not null)
    then
      l_code_trace := new code_trace(date_time  => systimestamp
                                    ,code_name  => utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(2))
                                    ,line_no    => utl_call_stack.unit_line(2)
                                    ,trace_data => substr(p_data, 1, 4000));
      self.stack_list.extend();
      self.stack_list(self.stack_list.last()) := l_code_trace;
    end if;
  end add_info;

  member procedure add_call_stack
  (
    self      in out nocopy call_info_stack
   ,p_comment in varchar2
  ) is
    l_depth      pls_integer;
    l_code_trace code_trace;
  begin
    if (self.trace_on = 1)
    then
      l_depth := utl_call_stack.dynamic_depth();
      for i in reverse 2 .. l_depth
      loop
        l_code_trace := new code_trace(code_name  => utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(i))
                                      ,line_no    => utl_call_stack.unit_line(i)
                                      ,date_time  => systimestamp
                                      ,trace_data => 'callstack.' || to_char(i - 1) || ' - ' || p_comment);
        self.stack_list.extend();
        self.stack_list(self.stack_list.last()) := l_code_trace;
      end loop;
    end if;
  end add_call_stack;

  member procedure add_stack
  (
    self    in out nocopy call_info_stack
   ,p_stack in call_info_stack
  ) is
  begin
    if (self.trace_on = 1)
    then
      self.stack_list := self.stack_list multiset union p_stack.stack_list;
    end if;
  end add_stack;

  member function is_empty(self in out nocopy call_info_stack) return boolean is
  begin
    return(self.stack_list is empty);
  end is_empty;

  member function is_not_empty(self in out nocopy call_info_stack) return boolean is
  begin
    return(self.stack_list is not empty);
  end is_not_empty;

  member function to_json return clob is
    l_json clob;
  begin
    if (self.trace_on = 1)
    then
      select json_transform(json_object(self returning clob)
                           ,remove '$.TRACE_ON'
                           ,remove '$.X_REQUEST_ID'
                           ,remove '$.REQUESTER_ID'
                           ,rename '$.STACK_LIST[*].DATE_TIME' = 'timestamp'
                           ,rename '$.STACK_LIST[*].CODE_NAME' = 'code'
                           ,rename '$.STACK_LIST[*].LINE_NO' = 'lineNumber'
                           ,rename '$.STACK_LIST[*].TRACE_DATA' = 'data'
                           ,rename '$.STACK_LIST' = 'stack')
        into l_json
        from dual;
    end if;

    return(l_json);
  end to_json;

end;
/
