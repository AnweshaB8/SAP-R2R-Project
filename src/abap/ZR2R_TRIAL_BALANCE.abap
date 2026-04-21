*&---------------------------------------------------------------------*
*& Program     : ZR2R_TRIAL_BALANCE
*& Description : R2R - Trial Balance ALV Report
*& Author      : KIIT SAP BDC Student
*& Date        : 2026
*& Module      : FI (Financial Accounting)
*&---------------------------------------------------------------------*
*& This report generates a Trial Balance for a given Company Code
*& and Fiscal Year / Period as part of the Record-to-Report process.
*& It uses ALV Grid for output and integrates with GL account balances.
*&---------------------------------------------------------------------*

REPORT ZR2R_TRIAL_BALANCE
  LINE-SIZE 255
  LINE-COUNT 0
  NO STANDARD PAGE HEADING
  MESSAGE-ID ZR2R_MSG.

*----------------------------------------------------------------------*
* TYPE DEFINITIONS
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_trial_balance,
         bukrs    TYPE bukrs,          " Company Code
         saknr    TYPE saknr,          " GL Account Number
         txt50    TYPE txt50,          " Account Description
         koart    TYPE koart,          " Account Type (A/D/K/S/M)
         hsalv    TYPE wrbtr,          " Debit Balance
         ssalv    TYPE wrbtr,          " Credit Balance
         saldo    TYPE wrbtr,          " Net Balance
         waers    TYPE waers,          " Currency
       END OF ty_trial_balance.

TYPES: tt_trial_balance TYPE STANDARD TABLE OF ty_trial_balance.

*----------------------------------------------------------------------*
* DATA DECLARATIONS
*----------------------------------------------------------------------*
DATA: gt_trial_balance TYPE tt_trial_balance,
      gs_trial_balance TYPE ty_trial_balance,
      gt_fieldcat      TYPE slis_t_fieldcat_alv,
      gs_fieldcat      TYPE slis_fieldcat_alv,
      gs_layout        TYPE slis_layout_alv,
      gs_sort          TYPE slis_sortinfo_alv,
      gt_sort          TYPE slis_t_sortinfo_alv,
      gv_repid         TYPE sy-repid,
      gv_total_debit   TYPE wrbtr,
      gv_total_credit  TYPE wrbtr.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_bukrs  TYPE bukrs OBLIGATORY DEFAULT '1000',   " Company Code
    p_gjahr  TYPE gjahr OBLIGATORY DEFAULT '2024',   " Fiscal Year
    p_monat  TYPE monat OBLIGATORY DEFAULT '12'.     " Posting Period
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS:
    s_saknr  FOR gs_trial_balance-saknr,             " GL Account Range
    s_koart  FOR gs_trial_balance-koart.             " Account Type
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* INITIALIZATION
*----------------------------------------------------------------------*
INITIALIZATION.
  gv_repid = sy-repid.

*----------------------------------------------------------------------*
* AT SELECTION SCREEN - Validation
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  PERFORM validate_inputs.

*----------------------------------------------------------------------*
* START OF SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM fetch_trial_balance_data.
  PERFORM calculate_totals.
  PERFORM build_fieldcat.
  PERFORM build_layout.
  PERFORM build_sort.
  PERFORM display_alv.

*----------------------------------------------------------------------*
* FORM: VALIDATE_INPUTS
*----------------------------------------------------------------------*
FORM validate_inputs.
  DATA: lv_check TYPE bukrs.

  " Validate Company Code
  SELECT SINGLE bukrs FROM t001 INTO lv_check
    WHERE bukrs = p_bukrs.
  IF sy-subrc <> 0.
    MESSAGE e001 WITH p_bukrs.
  ENDIF.

  " Validate Fiscal Year
  IF p_gjahr < 1900 OR p_gjahr > 2999.
    MESSAGE e002 WITH p_gjahr.
  ENDIF.

  " Validate Period
  IF p_monat < 1 OR p_monat > 16.
    MESSAGE e003 WITH p_monat.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: FETCH_TRIAL_BALANCE_DATA
*----------------------------------------------------------------------*
FORM fetch_trial_balance_data.
  DATA: lt_bsis  TYPE STANDARD TABLE OF bsis,
        lt_bsas  TYPE STANDARD TABLE OF bsas,
        ls_bsis  TYPE bsis,
        ls_skat  TYPE skat.

  CLEAR: gt_trial_balance.

  " Read GL account balances from GLT0 (GL Account Period Balances)
  SELECT g~saknr
         g~bukrs
         g~gjahr
         SUM( g~hslvt ) AS hslvt   " Balance carried fwd
         SUM( g~hsl01 ) AS hsl01   " Period 1
         SUM( g~hsl02 ) AS hsl02
         SUM( g~hsl03 ) AS hsl03
         SUM( g~hsl04 ) AS hsl04
         SUM( g~hsl05 ) AS hsl05
         SUM( g~hsl06 ) AS hsl06
         SUM( g~hsl07 ) AS hsl07
         SUM( g~hsl08 ) AS hsl08
         SUM( g~hsl09 ) AS hsl09
         SUM( g~hsl10 ) AS hsl10
         SUM( g~hsl11 ) AS hsl11
         SUM( g~hsl12 ) AS hsl12
    FROM glt0 AS g
    INTO TABLE @DATA(lt_glt0)
    WHERE g~bukrs = @p_bukrs
      AND g~gjahr = @p_gjahr
      AND g~saknr IN @s_saknr
    GROUP BY g~saknr g~bukrs g~gjahr.

  LOOP AT lt_glt0 INTO DATA(ls_glt0).
    CLEAR gs_trial_balance.

    gs_trial_balance-bukrs = ls_glt0-bukrs.
    gs_trial_balance-saknr = ls_glt0-saknr.

    " Calculate cumulative balance up to selected period
    DATA(lv_balance) = ls_glt0-hslvt.
    DO p_monat TIMES.
      CASE sy-index.
        WHEN 1.  lv_balance += ls_glt0-hsl01.
        WHEN 2.  lv_balance += ls_glt0-hsl02.
        WHEN 3.  lv_balance += ls_glt0-hsl03.
        WHEN 4.  lv_balance += ls_glt0-hsl04.
        WHEN 5.  lv_balance += ls_glt0-hsl05.
        WHEN 6.  lv_balance += ls_glt0-hsl06.
        WHEN 7.  lv_balance += ls_glt0-hsl07.
        WHEN 8.  lv_balance += ls_glt0-hsl08.
        WHEN 9.  lv_balance += ls_glt0-hsl09.
        WHEN 10. lv_balance += ls_glt0-hsl10.
        WHEN 11. lv_balance += ls_glt0-hsl11.
        WHEN 12. lv_balance += ls_glt0-hsl12.
      ENDCASE.
    ENDDO.

    gs_trial_balance-saldo = lv_balance.

    " Debit/Credit split
    IF lv_balance > 0.
      gs_trial_balance-hsalv = lv_balance.
      gs_trial_balance-ssalv = 0.
    ELSE.
      gs_trial_balance-hsalv = 0.
      gs_trial_balance-ssalv = ABS( lv_balance ).
    ENDIF.

    " Get Account Description
    SELECT SINGLE txt50 FROM skat INTO gs_trial_balance-txt50
      WHERE spras = sy-langu
        AND ktopl = ( SELECT ktopl FROM t001 WHERE bukrs = @p_bukrs )
        AND saknr = @ls_glt0-saknr.

    " Get Account Type
    SELECT SINGLE koart FROM ska1 INTO gs_trial_balance-koart
      WHERE ktopl = ( SELECT ktopl FROM t001 WHERE bukrs = @p_bukrs )
        AND saknr = @ls_glt0-saknr.

    IF s_koart IS INITIAL OR gs_trial_balance-koart IN s_koart.
      gs_trial_balance-waers = 'INR'.
      APPEND gs_trial_balance TO gt_trial_balance.
    ENDIF.

  ENDLOOP.

  IF gt_trial_balance IS INITIAL.
    MESSAGE s004 DISPLAY LIKE 'W'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: CALCULATE_TOTALS
*----------------------------------------------------------------------*
FORM calculate_totals.
  LOOP AT gt_trial_balance INTO gs_trial_balance.
    gv_total_debit  += gs_trial_balance-hsalv.
    gv_total_credit += gs_trial_balance-ssalv.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_FIELDCAT
*----------------------------------------------------------------------*
FORM build_fieldcat.
  CLEAR gt_fieldcat.

  DEFINE add_field.
    CLEAR gs_fieldcat.
    gs_fieldcat-fieldname    = &1.
    gs_fieldcat-seltext_l    = &2.
    gs_fieldcat-col_pos      = &3.
    gs_fieldcat-outputlen    = &4.
    gs_fieldcat-just         = &5.
    gs_fieldcat-no_zero      = &6.
    APPEND gs_fieldcat TO gt_fieldcat.
  END-OF-DEFINITION.

  add_field 'BUKRS'  'Company Code'         1  10 'L' ' '.
  add_field 'SAKNR'  'GL Account'           2  12 'L' ' '.
  add_field 'TXT50'  'Account Description'  3  40 'L' ' '.
  add_field 'KOART'  'Acct Type'            4   8 'C' ' '.
  add_field 'HSALV'  'Debit Balance'        5  18 'R' 'X'.
  add_field 'SSALV'  'Credit Balance'       6  18 'R' 'X'.
  add_field 'SALDO'  'Net Balance'          7  18 'R' ' '.
  add_field 'WAERS'  'Currency'             8   5 'C' ' '.

  " Mark currency and amount fields
  LOOP AT gt_fieldcat INTO gs_fieldcat
    WHERE fieldname = 'HSALV' OR fieldname = 'SSALV' OR fieldname = 'SALDO'.
    gs_fieldcat-cfieldname = 'WAERS'.
    gs_fieldcat-qfieldname = ''.
    gs_fieldcat-datatype   = 'CURR'.
    MODIFY gt_fieldcat FROM gs_fieldcat.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_LAYOUT
*----------------------------------------------------------------------*
FORM build_layout.
  CLEAR gs_layout.
  gs_layout-zebra            = 'X'.
  gs_layout-colwidth_optimize = 'X'.
  gs_layout-subtotals_text    = 'Subtotal:'.
  gs_layout-totals_text       = 'Grand Total:'.
  gs_layout-box_fieldname     = ''.
  gs_layout-coltab_fieldname  = ''.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_SORT
*----------------------------------------------------------------------*
FORM build_sort.
  CLEAR gs_sort.
  gs_sort-fieldname  = 'KOART'.
  gs_sort-spos       = 1.
  gs_sort-up         = 'X'.
  gs_sort-subtot     = 'X'.
  APPEND gs_sort TO gt_sort.

  CLEAR gs_sort.
  gs_sort-fieldname  = 'SAKNR'.
  gs_sort-spos       = 2.
  gs_sort-up         = 'X'.
  APPEND gs_sort TO gt_sort.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: DISPLAY_ALV
*----------------------------------------------------------------------*
FORM display_alv.
  DATA: ls_variant TYPE disvariant.
  ls_variant-report = gv_repid.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program      = gv_repid
      i_callback_user_command = 'USER_COMMAND'
      i_callback_top_of_page  = 'TOP_OF_PAGE'
      is_layout               = gs_layout
      it_fieldcat             = gt_fieldcat
      it_sort                 = gt_sort
      i_save                  = 'A'
      is_variant              = ls_variant
      i_default               = 'X'
    TABLES
      t_outtab                = gt_trial_balance
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: TOP_OF_PAGE
*----------------------------------------------------------------------*
FORM top_of_page.
  DATA: lt_header TYPE slis_t_listheader,
        ls_header TYPE slis_listheader.

  " Title
  ls_header-typ  = 'H'.
  ls_header-info = 'KIIT University — SAP BDC Project'.
  APPEND ls_header TO lt_header.

  ls_header-typ  = 'H'.
  ls_header-info = 'Record-to-Report | Trial Balance Report'.
  APPEND ls_header TO lt_header.

  CLEAR ls_header.

  " Company Code
  ls_header-typ  = 'S'.
  ls_header-key  = 'Company Code :'.
  ls_header-info = p_bukrs.
  APPEND ls_header TO lt_header.

  " Fiscal Year / Period
  ls_header-key  = 'Fiscal Year  :'.
  ls_header-info = p_gjahr.
  APPEND ls_header TO lt_header.

  ls_header-key  = 'Period       :'.
  ls_header-info = p_monat.
  APPEND ls_header TO lt_header.

  " Totals
  ls_header-typ  = 'A'.
  ls_header-key  = 'Total Debit  :'.
  ls_header-info = gv_total_debit.
  APPEND ls_header TO lt_header.

  ls_header-key  = 'Total Credit :'.
  ls_header-info = gv_total_credit.
  APPEND ls_header TO lt_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: USER_COMMAND (ALV Toolbar Events)
*----------------------------------------------------------------------*
FORM user_command USING r_ucomm     TYPE sy-ucomm
                        rs_selfield TYPE slis_selfield.
  CASE r_ucomm.
    WHEN '&IC1'.  " Double-click → Navigate to FS10N
      READ TABLE gt_trial_balance INTO gs_trial_balance
        INDEX rs_selfield-tabindex.
      IF sy-subrc = 0.
        SET PARAMETER ID 'BUK' FIELD p_bukrs.
        SET PARAMETER ID 'SAK' FIELD gs_trial_balance-saknr.
        SET PARAMETER ID 'GJR' FIELD p_gjahr.
        CALL TRANSACTION 'FS10N' AND SKIP FIRST SCREEN.
      ENDIF.
  ENDCASE.
ENDFORM.
