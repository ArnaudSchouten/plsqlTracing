create or replace type error_stack force authid current_user as object
(
-- attributes
  errors error_list,
-- non args constructor
  constructor function error_stack(self in out nocopy error_stack) return self as result,

-----------------------------------------------------------
-- members (TODO: use UTL_CALL_STACK)
-----------------------------------------------------------
-- (1)
  member procedure add_error
  (
    self    in out nocopy error_stack
   ,p_error in error_type
  ),

-- zet een fout op de stack obv een code
  member procedure add_error
  (
    self     in out nocopy error_stack
   ,p_error  in varchar2
   ,p_values in string_list default new string_list()
  ),

-- add another stack
  member procedure add_stack
  (
    self    in out nocopy error_stack
   ,p_stack in error_stack
  ),

  member function is_empty(self in out nocopy error_stack) return boolean,

  member function is_not_empty(self in out nocopy error_stack) return boolean,

  member function to_string return varchar2,

  member function to_json return clob,

-----------------------------------------------------------
-- static helpers
-----------------------------------------------------------
-- bepaal constraint naam o.b.v. de foutmelding
  static function get_constraint_name(p_sql_errm in varchar2) return varchar2,

-- check voor specifieke nn constraint
  static function is_not_null_violation(p_sql_errm in varchar2) return boolean,

-- check voor locking fouten
  static function is_locking_error(p_sql_errm in varchar2) return boolean
)
;
/
create or replace type body error_stack as

  -- constructor
  constructor function error_stack(self in out nocopy error_stack) return self as result is
  begin
    self.errors := new error_list();
    return;
  end;

  -- members
  member procedure add_error
  (
    self    in out nocopy error_stack
   ,p_error in error_type
  ) is
  begin
    self.errors.extend();
    self.errors(self.errors.last()) := p_error;
  end add_error;

  member procedure add_error
  (
    self     in out nocopy error_stack
   ,p_error  in varchar2
   ,p_values in string_list default new string_list()
  ) is
    -- variables
    l_error error_type;
    --
    -- private function
    function get_error_msg(p_code in varchar2) return error_type is
      l_error error_type;
    begin
      select /*+ result_cache */
       new error_type(err_code => t.code, err_msg => t.melding)
        into l_error
        from alg_fout_meldingen t
       where ((t.code = p_code) or (t.constraint_name = regexp_substr(p_code, '(\.)([^.]+)(\))', 1, 1, 'i', 2)));

      return(l_error);
    exception
      when no_data_found then
        return(l_error);
    end get_error_msg;

    procedure replace_msg_parameters
    (
      p_error  in out nocopy error_type
     ,p_values in string_list default new string_list()
    ) is
    begin
      if (p_values is not empty)
      -- gevonden; eens zien of we parameters moeten vervangen
      then
        for i in 1 .. p_values.count()
        loop
          p_error.err_msg := replace(p_error.err_msg, '<p' || i || '>', p_values(i));
        end loop;
      end if;

    end replace_msg_parameters;

  begin
    -- haal de error op obv de code of sqlerrm
    l_error := get_error_msg(p_code => p_error);

    if (l_error is not null)
    then
      replace_msg_parameters(p_error => l_error, p_values => p_values);
      self.add_error(p_error => l_error);
    else
      -- niet gevonden (bijv. when others)
      --
      -- special cases
      case
        when error_stack.is_not_null_violation(p_sql_errm => p_error) then
          -- not null
          add_error(p_error => 'OCP-00005', p_values => new string_list(replace(regexp_substr(p_error, '(\.")((.)+)("\))', 1, 1, 'i', 2), '"')));
        when error_stack.is_locking_error(p_sql_errm => p_error) then
          -- lock detected
          add_error(p_error => 'OCP-00006');
        else
          -- default: just log
          self.add_error(p_error => new error_type('OCP-99999', p_error));
      end case;

    end if;

  end add_error;

  -- add another stack
  member procedure add_stack
  (
    self    in out nocopy error_stack
   ,p_stack in error_stack
  ) is
  begin
    if (p_stack is not null and p_stack.errors is not empty)
    then
      self.errors := self.errors multiset union p_stack.errors;
    end if;
  end add_stack;

  member function is_empty(self in out nocopy error_stack) return boolean is
  begin
    return(self.errors is empty);
  end is_empty;

  member function is_not_empty(self in out nocopy error_stack) return boolean is
  begin
    return(self.errors is not empty);
  end is_not_empty;

  member function to_string return varchar2 is
    l_error_string varchar2(32000);
  begin
    if (self.errors is not empty)
    then
      for i in self.errors.first() .. self.errors.count()
      loop
        l_error_string := l_error_string || self.errors(i).err_code || ' - ' || self.errors(i).err_msg || chr(10);
      end loop;
    end if;

    return(rtrim(l_error_string, chr(10)));
  end to_string;

  member function to_json return clob is
    l_json clob;
  begin
    select json_transform(json_object(self returning clob)
                         ,rename '$.ERRORS[*].ERR_CODE' = 'code'
                         ,rename '$.ERRORS[*].ERR_MSG' = 'message'
                         ,rename '$.ERRORS' = 'errors')
      into l_json
      from dual;
    return(l_json);
  end to_json;

  static function get_constraint_name(p_sql_errm in varchar2) return varchar2 is
  begin
    return(regexp_substr(p_sql_errm, '(\.)([^.]+)(\))', 1, 1, 'i', 2));
  end get_constraint_name;

  -- handy static function om een 'not null' violation te bepalen
  static function is_not_null_violation(p_sql_errm in varchar2) return boolean is
  begin
    return(regexp_like(p_sql_errm, '^(ORA-01400)|(ORA-01407)', 'i'));
  end is_not_null_violation;

  -- handy static function om een 'lock' fout te bepalen
  static function is_locking_error(p_sql_errm in varchar2) return boolean is
  begin
    return(regexp_like(p_sql_errm, '^(ORA-00054)', 'i'));
  end is_locking_error;

end;
/
