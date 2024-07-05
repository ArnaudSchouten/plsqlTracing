create or replace type ocp_response_type force authid current_user as object
(
------------------------------------------------------
-- attributes
------------------------------------------------------
  error_messages error_stack,
  call_stack     call_info_stack,
------------------------------------------------------
-- members
------------------------------------------------------
  member procedure init_stacks(self in out nocopy ocp_response_type),

  member procedure persist_trace
  (
    self      in out nocopy ocp_response_type
   ,p_cmp_id  in number
   ,p_cmpcode in varchar2
  ),

  member procedure copy_traces
  (
    self    in out nocopy ocp_response_type
   ,p_other in ocp_response_type
  )
)
not final not instantiable;
/
create or replace type body ocp_response_type as

  member procedure init_stacks(self in out nocopy ocp_response_type) is
  begin
    if (self.error_messages is null)
    then
      self.error_messages := new error_stack();
    end if;
  
    if (self.call_stack is null)
    then
      self.call_stack := new call_info_stack();
    end if;
  end init_stacks;

  member procedure persist_trace
  (
    self      in out nocopy ocp_response_type
   ,p_cmp_id  in number
   ,p_cmpcode in varchar2
  ) is
    pragma autonomous_transaction;
  begin
    -- log trace
    if (self.call_stack.trace_on = 1 and self.call_stack.is_not_empty())
    then
      insert into ocp_db_trace_logging
        (cmp_id
        ,cmpcode
        ,date_time
        ,x_request_id
        ,requester_id
        ,trace_data)
      values
        (p_cmp_id
        ,p_cmpcode
        ,sysdate
        ,self.call_stack.x_request_id
        ,self.call_stack.requester_id
        ,self.call_stack.to_json());
    end if;
    -- log errors
    if (self.error_messages.is_not_empty())
    then
      insert into ocp_db_trace_logging
        (cmp_id
        ,cmpcode
        ,date_time
        ,trace_data)
      values
        (p_cmp_id
        ,p_cmpcode
        ,sysdate
        ,self.error_messages.to_json());
    end if;
    commit;
  end persist_trace;

  member procedure copy_traces
  (
    self    in out nocopy ocp_response_type
   ,p_other in ocp_response_type
  ) is
  begin
    if (p_other is not null)
    then
      self.error_messages.add_stack(p_other.error_messages);
    
      if (self.call_stack.trace_on = 1)
      then
        self.call_stack.add_stack(p_other.call_stack);
        self.call_stack.x_request_id := p_other.call_stack.x_request_id;
        self.call_stack.requester_id := p_other.call_stack.requester_id;
      end if;
    end if;  
  end copy_traces;

end;
/
