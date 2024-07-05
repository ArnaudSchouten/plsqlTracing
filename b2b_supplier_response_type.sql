create or replace type b2b_supplier_response_type force under ocp_response_type
(
-----------------------------------------------------------
-- attributes
-----------------------------------------------------------
  supplier_id number, /* internal id */
  tracking_id number, /* external id */
  kvk_nummer  integer,
-----------------------------------------------------------
-- constructors
-----------------------------------------------------------
-- no args constructor
  constructor function b2b_supplier_response_type(self in out nocopy b2b_supplier_response_type) return self as result,
------------------------------------------------------
-- members
------------------------------------------------------
-- store trace in tabel
  member procedure persist_trace(self in out nocopy b2b_supplier_response_type)
)
not final;
/
create or replace type body b2b_supplier_response_type as
  -----------------------------------------------------------
  -- constructors
  -----------------------------------------------------------
  -- non args constructor
  constructor function b2b_supplier_response_type(self in out nocopy b2b_supplier_response_type) return self as result is
  begin
    self.init_stacks();
    return;
  end;
  ------------------------------------------------------
  -- members
  ------------------------------------------------------
  member procedure persist_trace(self in out nocopy b2b_supplier_response_type) is
  begin
    self.persist_trace(p_cmp_id => self.supplier_id, p_cmpcode => 'LEV');
  end persist_trace;

end;
/
