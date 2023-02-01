FUNCTION zfm_tp_teste .
*"----------------------------------------------------------------------
*"*"Interface local:
*"  IMPORTING
*"     REFERENCE(IS_CUSTOMER) TYPE  ZSD_S_BUPA_CLIENTE
*"     REFERENCE(IS_ADDRESS) TYPE  ZSD_S_BUPA_ENDERECO
*"     REFERENCE(IV_TESTRUN) TYPE  BOOLE_D DEFAULT ABAP_FALSE
*"  EXPORTING
*"     REFERENCE(EV_PARTNER) TYPE  BU_PARTNER
*"     REFERENCE(EV_MENSAGEM) TYPE  STRING
*"----------------------------------------------------------------------
* IS_CUSTOMER:
*  NOME	        - BU_NAME1TX  - Nome completo
*  EMAIL        - AD_SMTPADR  - Email
*  CELULAR      - AD_TLNMBR1  - Celular
*  TELEFONE	    - AD_TLNMBR1  - Telefone
*  CPF          - BPTAXNUM    - CPF p/ pessoas fisicas
*  CNPJ         - BPTAXNUM    - CNPJ p/ pessoas jurificas
*  TIPO	        - CHAR10      - F: FISICA / J: JURIDICA
* IS_ADDRESS:
*  LOGRADOURO   - AD_STR_OLD  - Rua
*  BAIRRO	    - AD_CITY2    - Bairro
*  NUMERO	    - AD_HSNM1    - Numero
*  COMPLEMENTO  - AD_HSNM2    - Complemento
*  CIDADE	    - AD_CITY1    - Cidade
*  ESTADO	    - REGIO       - Estado
*  CEP          - AD_PSTCD1   - CEP

  DATA:
    ls_bpdata  TYPE cvis_ei_extern,
    lv_partner TYPE bu_partner,
    lv_error   TYPE string.

  CLEAR: ev_partner, ev_mensagem,
         ls_bpdata, lv_partner, lv_error.

  "Recupera numero do parceiro
  PERFORM f_get_existing_partner USING is_customer
                              CHANGING lv_partner.

  "Preenche dados do parceiro
  PERFORM f_fill_partner USING lv_partner
                               is_customer
                               is_address
                      CHANGING ls_bpdata.

  "Preenche dados do cliente
  PERFORM f_fill_customer USING lv_partner
                                is_customer
                                is_address
                       CHANGING ls_bpdata.

  "Preenche dados do fornecedor
  PERFORM f_fill_vendor USING lv_partner
                              is_customer
                              is_address
                     CHANGING ls_bpdata.

  "Atualiza / cria parceiro
  PERFORM f_maintain USING ls_bpdata
                           iv_testrun
                  CHANGING lv_partner
                           lv_error.

  IF lv_error IS NOT INITIAL.
    "Retorna erro
    ev_mensagem = lv_error.

  ELSE.
    "Retorna numero do BP
    ev_partner = lv_partner.

    "Retorna sucesso
    ev_mensagem = 'Sucesso'.
  ENDIF.

ENDFUNCTION.

*&---------------------------------------------------------------------*
*& FORM f_get_existing_partner
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_get_existing_partner USING ps_cust_in TYPE zsd_s_bupa_cliente
                         CHANGING c_partner  TYPE bu_partner.

  CLEAR c_partner.

  "Recupera BP pelo taxnum
  SELECT SINGLE partner
    FROM dfkkbptaxnum
    INTO c_partner
    WHERE ( ( taxnum = ps_cust_in-cpf  AND taxtype = 'BR2' )
         OR ( taxnum = ps_cust_in-cnpj AND taxtype = 'BR1'  ) ).

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_partner
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_partner USING p_partnerno TYPE bu_partner
                          ps_cust_in  TYPE zsd_s_bupa_cliente
                          ps_addr_in  TYPE zsd_s_bupa_endereco
                 CHANGING c_data      TYPE cvis_ei_extern.

  DATA:
    lv_partguid  TYPE but000-partner_guid,
    lv_firstname TYPE string,
    lv_lastname  TYPE string.

  IF p_partnerno IS INITIAL.
    "Preenche indicador
    c_data-partner-header-object_task = 'I'. "Criacao

    "Cria GUID
    TRY .
        lv_partguid = cl_system_uuid=>if_system_uuid_static~create_uuid_c32( ).
      CATCH cx_uuid_error.
    ENDTRY.

  ELSE.
    "Preenche indicador
    c_data-partner-header-object_task = 'M'. "Atualizacao

    "Recupera GUID
    SELECT SINGLE partner_guid
      FROM but000
      INTO lv_partguid
      WHERE partner = p_partnerno.

  ENDIF.

  "Preenche dados de cabecalho
  c_data-partner-header-object_instance-bpartner     = p_partnerno.
  c_data-partner-header-object_instance-bpartnerguid = lv_partguid.

  "Dados especificos por tipo de parceiro
  CASE ps_cust_in-tipo(1).
    WHEN 'F'.
      "Preenche dados de controle
      c_data-partner-central_data-common-data-bp_control-category = '1'. "pessoa
      c_data-partner-central_data-common-data-bp_control-grouping = 'BP02'.

      "Preenche dados centrais
      c_data-partner-central_data-common-data-bp_centraldata-searchterm1         = 'SAC'.
      c_data-partner-central_data-common-data-bp_centraldata-searchterm2         = ps_cust_in-cpf.
      c_data-partner-central_data-common-data-bp_centraldata-title_key           = '0001'.
      c_data-partner-central_data-common-data-bp_centraldata-partnerlanguage     = 'PT'.
      c_data-partner-central_data-common-data-bp_centraldata-partnerlanguageiso  = 'PT'.
      c_data-partner-central_data-common-datax-bp_centraldata-searchterm1        = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-searchterm2        = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-title_key          = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-partnerlanguage    = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-partnerlanguageiso = abap_true.

      "Preenche dados pessoais
      PERFORM f_split_fullname USING ps_cust_in-nome
                            CHANGING c_data-partner-central_data-common-data-bp_person-firstname
                                     c_data-partner-central_data-common-data-bp_person-lastname.
      c_data-partner-central_data-common-data-bp_person-namcountry             = 'BR'.
      c_data-partner-central_data-common-data-bp_person-namcountryiso          = 'BR'.
      c_data-partner-central_data-common-data-bp_person-sex                    = '1'.
      c_data-partner-central_data-common-data-bp_person-birthplace             = 'Nilopolis'.
      c_data-partner-central_data-common-data-bp_person-birthdate              = '19000101'.
      c_data-partner-central_data-common-data-bp_person-maritalstatus          = '1'.
      c_data-partner-central_data-common-data-bp_person-correspondlanguage     = 'PT'.
      c_data-partner-central_data-common-data-bp_person-correspondlanguageiso  = 'PT'.
      c_data-partner-central_data-common-data-bp_person-gender                 = '1'.
      c_data-partner-central_data-common-datax-bp_person-firstname             = abap_true.
      c_data-partner-central_data-common-datax-bp_person-lastname              = abap_true.
      c_data-partner-central_data-common-datax-bp_person-namcountry            = abap_true.
      c_data-partner-central_data-common-datax-bp_person-namcountryiso         = abap_true.
      c_data-partner-central_data-common-datax-bp_person-sex                   = abap_true.
      c_data-partner-central_data-common-datax-bp_person-birthplace            = abap_true.
      c_data-partner-central_data-common-datax-bp_person-birthdate             = abap_true.
      c_data-partner-central_data-common-datax-bp_person-maritalstatus         = abap_true.
      c_data-partner-central_data-common-datax-bp_person-correspondlanguage    = abap_true.
      c_data-partner-central_data-common-datax-bp_person-correspondlanguageiso = abap_true.
      c_data-partner-central_data-common-datax-bp_person-gender                = abap_true.

      "Preenche CPF
      c_data-partner-central_data-taxnumber-current_state = abap_true.
      c_data-partner-central_data-taxnumber-common-data-nat_person  = abap_true.  "pessoa fisica
      c_data-partner-central_data-taxnumber-common-datax-nat_person = abap_true.
      APPEND INITIAL LINE TO c_data-partner-central_data-taxnumber-taxnumbers[] ASSIGNING FIELD-SYMBOL(<fs_fistax>).
      <fs_fistax>-task = 'M'.
      <fs_fistax>-data_key-taxtype  = 'BR2'.
      <fs_fistax>-data_key-taxnumber = ps_cust_in-cpf.

    WHEN 'J'.
      "Preenche dados de controle
      c_data-partner-central_data-common-data-bp_control-category = '2'. "organizacao
      c_data-partner-central_data-common-data-bp_control-grouping = 'BP02'.

      "Preenche dados centrais
      c_data-partner-central_data-common-data-bp_centraldata-searchterm1         = 'SAC'.
      c_data-partner-central_data-common-data-bp_centraldata-searchterm2         = ps_cust_in-cnpj.
      c_data-partner-central_data-common-data-bp_centraldata-title_key           = '0003'.
      c_data-partner-central_data-common-data-bp_centraldata-partnerlanguage     = 'PT'.
      c_data-partner-central_data-common-data-bp_centraldata-partnerlanguageiso  = 'PT'.
      c_data-partner-central_data-common-datax-bp_centraldata-searchterm1        = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-searchterm2        = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-title_key          = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-partnerlanguage    = abap_true.
      c_data-partner-central_data-common-datax-bp_centraldata-partnerlanguageiso = abap_true.

      "Preenche dados organizacionais
      c_data-partner-central_data-common-data-bp_organization-name1  = ps_cust_in-nome.
      c_data-partner-central_data-common-datax-bp_organization-name1 = abap_true.

      "Preenche CNPJ
      c_data-partner-central_data-taxnumber-current_state = abap_true.
      c_data-partner-central_data-taxnumber-common-data-nat_person  = abap_false.
      c_data-partner-central_data-taxnumber-common-datax-nat_person = abap_true.
      APPEND INITIAL LINE TO c_data-partner-central_data-taxnumber-taxnumbers[] ASSIGNING FIELD-SYMBOL(<fs_jurtax>).
      <fs_jurtax>-task = 'M'.
      <fs_jurtax>-data_key-taxtype  = 'BR1'.
      <fs_jurtax>-data_key-taxnumber = ps_cust_in-cnpj.

  ENDCASE.

  "Preenche comunicacao (telefone, celular e email)
  PERFORM f_fill_partner_communication USING ps_cust_in
                                    CHANGING c_data-partner-central_data-communication.

  "Preenche endereco
  PERFORM f_fill_partner_address USING ps_addr_in
                              CHANGING c_data-partner-central_data-address.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_customer
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_customer USING p_partnerno TYPE bu_partner
                           ps_cust_in  TYPE zsd_s_bupa_cliente
                           ps_addr_in  TYPE zsd_s_bupa_endereco
                  CHANGING c_data      TYPE cvis_ei_extern.

  "Cabecalho
  c_data-customer-header-object_instance-kunnr = p_partnerno.

  "Preenche indicador
  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM kna1
      WHERE kunnr = @p_partnerno.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_data-customer-header-object_task = 'I'.
    c_data-ensure_create-create_customer = abap_true.
  ELSE.
    c_data-customer-header-object_task = 'U'.
    c_data-ensure_create-create_customer = abap_false.
  ENDIF.

  "Dados gerais
  c_data-customer-central_data-central-data-ktokd      = 'CUST'.
  c_data-customer-central_data-central-data-cfopc      = '06'.
  c_data-customer-central_data-central-data-icmstaxpay = 'NC'.
  c_data-customer-central_data-central-data-decregpc   = 'CM'.
  c_data-customer-central_data-central-datax-ktokd      = abap_true.
  c_data-customer-central_data-central-datax-cfopc      = abap_true.
  c_data-customer-central_data-central-datax-icmstaxpay = abap_true.
  c_data-customer-central_data-central-datax-decregpc   = abap_true.

  "Preenche roles
  PERFORM f_fill_customer_roles USING p_partnerno
                             CHANGING c_data-partner-central_data-role.

  "Preenche classificacao fiscal
  PERFORM f_fill_customer_taxind CHANGING c_data-customer-central_data-tax_ind.

  "Preenche ampliacao de empresas
  PERFORM f_fill_customer_company USING p_partnerno
                               CHANGING c_data-customer-company_data.

  "Preenche ampliacao de vendas
  PERFORM f_fill_customer_sales USING p_partnerno
                             CHANGING c_data-customer-sales_data.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_vendor
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_vendor USING p_partnerno TYPE bu_partner
                         ps_cust_in  TYPE zsd_s_bupa_cliente
                         ps_addr_in  TYPE zsd_s_bupa_endereco
                CHANGING c_data      TYPE cvis_ei_extern.

  "Cabecalho
  c_data-vendor-header-object_instance-lifnr = p_partnerno.

  "Preenche indicador
  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM lfa1
      WHERE lifnr = @p_partnerno.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_data-vendor-header-object_task = 'I'.
    c_data-ensure_create-create_vendor = abap_true.
  ELSE.
    c_data-vendor-header-object_task = 'U'.
    c_data-ensure_create-create_vendor = abap_false.
  ENDIF.
  "Dados gerais
  c_data-vendor-central_data-central-data-ktokk      = 'SUPL'.
  c_data-vendor-central_data-central-data-icmstaxpay = 'NC'.
  c_data-vendor-central_data-central-data-decregpc   = 'CM'.
  c_data-vendor-central_data-central-datax-ktokk      = abap_true.
  c_data-vendor-central_data-central-datax-icmstaxpay = abap_true.
  c_data-vendor-central_data-central-datax-decregpc   = abap_true.

  "Preenche roles
  PERFORM f_fill_vendor_roles USING p_partnerno
                           CHANGING c_data-partner-central_data-role.

  "Preenche ampliacao de empresas
  PERFORM f_fill_vendor_company USING p_partnerno
                             CHANGING c_data-vendor-company_data.

  "Preenche ampliacao de compras
  PERFORM f_fill_vendor_purchasing USING p_partnerno
                                CHANGING c_data-vendor-purchasing_data.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_maintain
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_maintain USING ps_data   TYPE cvis_ei_extern
                      p_testrun TYPE boole_d
             CHANGING c_partner TYPE bu_partner
                      c_error   TYPE string.

  DATA:
    lt_return_map TYPE mdg_bs_bp_msgmap_t,
    lt_return     TYPE bapiretm,
    lv_testrun    TYPE boole_d VALUE abap_false.

  CLEAR c_error.

  "Valida dados do parceiro
  cl_md_bp_maintain=>validate_single( EXPORTING i_data                   = ps_data
                                                iv_suppress_taxjur_check = ' '
                                      IMPORTING et_return_map            = lt_return_map[] ).

  "Recupera erros
  LOOP AT lt_return_map[] ASSIGNING FIELD-SYMBOL(<fs_retmap>)
    WHERE type CA 'EAX'.
    c_error = <fs_retmap>-message.
    IF c_error IS INITIAL.
      MESSAGE ID <fs_retmap>-id TYPE <fs_retmap>-type NUMBER <fs_retmap>-number
        WITH <fs_retmap>-message_v1 <fs_retmap>-message_v2
             <fs_retmap>-message_v3 <fs_retmap>-message_v4
        INTO c_error.
    ENDIF.
  ENDLOOP.

  CHECK c_error IS INITIAL.

  lv_testrun = p_testrun.

  "Atualiza parceiro
  cl_md_bp_maintain=>maintain( EXPORTING i_data     = VALUE #( ( ps_data ) )
                                         i_test_run = lv_testrun
                               IMPORTING e_return   = lt_return[] ).

  IF lv_testrun = abap_false.
    "Importa ultimo parceiro atualizado
    IMPORT lv_partner TO c_partner FROM MEMORY ID 'BUP_MEMORY_PARTNER'.
  ENDIF.

  "Recupera erros
  LOOP AT lt_return[] ASSIGNING FIELD-SYMBOL(<fs_return>).
    LOOP AT <fs_return>-object_msg[] ASSIGNING FIELD-SYMBOL(<fs_msg>)
      WHERE type CA 'EAX'.
      c_error = <fs_msg>-message.
      IF c_error IS INITIAL.
        MESSAGE ID <fs_msg>-id TYPE <fs_msg>-type NUMBER <fs_msg>-number
          WITH <fs_msg>-message_v1 <fs_msg>-message_v2
               <fs_msg>-message_v3 <fs_msg>-message_v4
          INTO c_error.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

  IF c_error IS INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_split_fullname
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_split_fullname USING p_fullname
                   CHANGING c_firstname
                            c_lastname.

  DATA:
    lv_name TYPE string.

  SPLIT p_fullname AT ' ' INTO TABLE DATA(lt_names).

  IF lines( lt_names ) <= 2.
    READ TABLE lt_names INTO c_firstname INDEX 1.
    READ TABLE lt_names INTO c_lastname  INDEX 2.
  ELSE.
    READ TABLE lt_names INTO lv_name INDEX 1.
    CONCATENATE c_firstname lv_name INTO c_firstname SEPARATED BY space.
    DELETE lt_names INDEX 1.

    READ TABLE lt_names INTO lv_name INDEX 1.
    CONCATENATE c_firstname lv_name INTO c_firstname SEPARATED BY space.
    DELETE lt_names INDEX 1.

    LOOP AT lt_names INTO lv_name.
      CONCATENATE c_lastname lv_name INTO c_lastname SEPARATED BY space.
    ENDLOOP.
  ENDIF.

  CONDENSE c_firstname.
  CONDENSE c_lastname.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_partner_address
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_partner_address USING ps_addr_in  TYPE zsd_s_bupa_endereco
                         CHANGING cs_bupaaddr TYPE bus_ei_address.

  cs_bupaaddr-current_state = abap_true.

  "Preenche endereco
  APPEND INITIAL LINE TO cs_bupaaddr-addresses[] ASSIGNING FIELD-SYMBOL(<fs_addr>).
  <fs_addr>-task = 'M'.
  <fs_addr>-currently_valid = abap_true.
  <fs_addr>-data_key-operation = 'XXDFLT'. "default
  <fs_addr>-data-postal-data-standardaddress  = abap_true.
  <fs_addr>-data-postal-data-city             = ps_addr_in-cidade.
  <fs_addr>-data-postal-data-district         = ps_addr_in-bairro.
  <fs_addr>-data-postal-data-country          = 'BR'.
  <fs_addr>-data-postal-data-countryiso       = 'BR'.
  <fs_addr>-data-postal-data-house_no         = ps_addr_in-numero.
  <fs_addr>-data-postal-data-house_no2        = ps_addr_in-complemento.
  <fs_addr>-data-postal-data-langu            = 'PT'.
  <fs_addr>-data-postal-data-languiso         = 'PT'.
  <fs_addr>-data-postal-data-postl_cod1       = ps_addr_in-cep.
  <fs_addr>-data-postal-data-region           = ps_addr_in-estado.
  <fs_addr>-data-postal-data-street           = ps_addr_in-logradouro.
  <fs_addr>-data-postal-datax-standardaddress = abap_true.
  <fs_addr>-data-postal-datax-city            = abap_true.
  <fs_addr>-data-postal-datax-district        = abap_true.
  <fs_addr>-data-postal-datax-country         = abap_true.
  <fs_addr>-data-postal-datax-countryiso      = abap_true.
  <fs_addr>-data-postal-datax-house_no        = abap_true.
  <fs_addr>-data-postal-datax-house_no2       = abap_true.
  <fs_addr>-data-postal-datax-langu           = abap_true.
*  <fs_addr>-data-postal-datax-languiso        = abap_true.
  <fs_addr>-data-postal-datax-postl_cod1      = abap_true.
  <fs_addr>-data-postal-datax-region          = abap_true.
  <fs_addr>-data-postal-datax-street          = abap_true.

  "Le domicilio fiscal
  SELECT SINGLE taxjurcode
    FROM j_1btreg_city
    INTO @<fs_addr>-data-postal-data-transpzone
    WHERE country     = 'BR'
      AND region      = @ps_addr_in-estado
      AND pstcd_from <= @ps_addr_in-cep
      AND pstcd_to   >= @ps_addr_in-cep.
  <fs_addr>-data-postal-data-taxjurcode  = <fs_addr>-data-postal-data-transpzone.
  <fs_addr>-data-postal-datax-transpzone = abap_true.
  <fs_addr>-data-postal-datax-taxjurcode = abap_true.

  "Le timezone
  SELECT SINGLE tzone
    FROM ttz5s
    INTO @<fs_addr>-data-postal-data-time_zone
    WHERE land1 = 'BR'
      AND bland = @ps_addr_in-estado.
  IF sy-subrc <> 0.
    <fs_addr>-data-postal-data-time_zone = 'BRZLEA'.
  ENDIF.
  <fs_addr>-data-postal-datax-time_zone = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_partner_communication
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_partner_communication USING ps_cust_in TYPE zsd_s_bupa_cliente
                               CHANGING cs_bupacom TYPE bus_ei_communication.

  "Preenche telefone
  cs_bupacom-phone-current_state = abap_true.
  APPEND INITIAL LINE TO cs_bupacom-phone-phone[] ASSIGNING FIELD-SYMBOL(<fs_phone>).
  <fs_phone>-contact-task = 'M'.
  <fs_phone>-currently_valid = abap_true.
  <fs_phone>-contact-data-country     = 'BR'.
  <fs_phone>-contact-data-countryiso  = 'BR'.
  <fs_phone>-contact-data-telephone   = ps_cust_in-telefone.
  <fs_phone>-contact-datax-country    = abap_true.
  <fs_phone>-contact-datax-countryiso = abap_true.
  <fs_phone>-contact-datax-telephone  = abap_true.

  "Preenche celular
  cs_bupacom-phone-current_state = abap_true.
  APPEND INITIAL LINE TO cs_bupacom-phone-phone[] ASSIGNING FIELD-SYMBOL(<fs_celphone>).
  <fs_celphone>-contact-task = 'M'.
  <fs_celphone>-currently_valid = abap_true.
  <fs_celphone>-contact-data-country     = 'BR'.
  <fs_celphone>-contact-data-countryiso  = 'BR'.
  <fs_celphone>-contact-data-telephone   = ps_cust_in-celular.
  <fs_celphone>-contact-data-r_3_user    = '2'.  "celular
  <fs_celphone>-contact-datax-country    = abap_true.
  <fs_celphone>-contact-datax-countryiso = abap_true.
  <fs_celphone>-contact-datax-telephone  = abap_true.
  <fs_celphone>-contact-datax-r_3_user   = abap_true.

  "Preenche email
  cs_bupacom-smtp-current_state = abap_true.
  APPEND INITIAL LINE TO cs_bupacom-smtp-smtp[] ASSIGNING FIELD-SYMBOL(<fs_email>).
  <fs_email>-contact-task = 'M'.
  <fs_email>-currently_valid = abap_true.
  <fs_email>-contact-data-e_mail  = ps_cust_in-email.
  <fs_email>-contact-datax-e_mail = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_customer_roles
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_customer_roles USING p_partnerno TYPE bu_partner
                        CHANGING c_roles     TYPE bus_ei_roles.

  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM but100
      WHERE partner = p_partnerno
        AND rltyp   = 'FLCU01'.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_roles-current_state = abap_true.

    "Insere role FLCU01 - Cliente
    APPEND INITIAL LINE TO c_roles-roles[] ASSIGNING FIELD-SYMBOL(<fs_flcu01>).
    <fs_flcu01>-task = 'I'. "Insert
    <fs_flcu01>-currently_valid = abap_true.
    <fs_flcu01>-data_key        = 'FLCU01'.
    <fs_flcu01>-data-rolecategory = 'FLCU01'.
    <fs_flcu01>-data-valid_from   = '18000101'.
    <fs_flcu01>-data-valid_to     = '99991231'.
    <fs_flcu01>-datax-valid_from  = abap_true.
    <fs_flcu01>-datax-valid_to    = abap_true.
  ENDIF.

  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM but100
      WHERE partner = p_partnerno
        AND rltyp   = 'FLCU00'.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_roles-current_state = abap_true.

    "Insere role FLCU00 - Cliente (contab.financ.)
    APPEND INITIAL LINE TO c_roles-roles[] ASSIGNING FIELD-SYMBOL(<fs_flcu00>).
    <fs_flcu00>-task = 'I'. "Insert
    <fs_flcu00>-currently_valid = abap_true.
    <fs_flcu00>-data_key        = 'FLCU00'.
    <fs_flcu00>-data-rolecategory = 'FLCU00'.
    <fs_flcu00>-data-valid_from   = '18000101'.
    <fs_flcu00>-data-valid_to     = '99991231'.
    <fs_flcu00>-datax-valid_from  = abap_true.
    <fs_flcu00>-datax-valid_to    = abap_true.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_customer_taxind
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_customer_taxind CHANGING c_taxind TYPE cmds_ei_cmd_tax_ind.

  c_taxind-current_state = abap_true.

  "Preenche classificacao fiscal
  APPEND INITIAL LINE TO c_taxind-tax_ind[] ASSIGNING FIELD-SYMBOL(<fs_taxind>).
  <fs_taxind>-task = 'M'.
  <fs_taxind>-data_key-aland = 'BR'.
  <fs_taxind>-data_key-tatyp = 'IBRX'.
  <fs_taxind>-data-taxkd  = '1'.
  <fs_taxind>-datax-taxkd = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_customer_company
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_customer_company USING p_partnerno TYPE bu_partner
                          CHANGING c_company   TYPE cmds_ei_cmd_company.

  c_company-current_state = abap_true.

  "Preenche dados da empresa
  APPEND INITIAL LINE TO c_company-company[] ASSIGNING FIELD-SYMBOL(<fs_company>).
  <fs_company>-task = 'M'.
  <fs_company>-data_key-bukrs = 'BR11'.
  <fs_company>-data-frgrp  = 'F023'.
  <fs_company>-data-akont  = '0011201001'.
  <fs_company>-data-fdgrv  = 'C001'.
  <fs_company>-data-vzskz  = 'Z1'.
  <fs_company>-data-zterm  = 'D000'.
  <fs_company>-data-zwels  = 'F'.
  <fs_company>-data-hbkid  = '75501'.
  <fs_company>-datax-frgrp = abap_true.
  <fs_company>-datax-akont = abap_true.
  <fs_company>-datax-fdgrv = abap_true.
  <fs_company>-datax-vzskz = abap_true.
  <fs_company>-datax-zterm = abap_true.
  <fs_company>-datax-zwels = abap_true.
  <fs_company>-datax-hbkid = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_customer_sales
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_customer_sales USING p_partnerno TYPE bu_partner
                        CHANGING c_sales     TYPE cmds_ei_cmd_sales.

  c_sales-current_state = abap_true.

  "Preenche area de vendas
  APPEND INITIAL LINE TO c_sales-sales[] ASSIGNING FIELD-SYMBOL(<fs_sales>).
  <fs_sales>-task = 'M'.
  <fs_sales>-data_key-vkorg = '1102'.
  <fs_sales>-data_key-vtweg = '40'.
  <fs_sales>-data_key-spart = '00'.
  <fs_sales>-data-bzirk    = 'BR0003'.
  <fs_sales>-data-vkbur    = 'BR50'.
  <fs_sales>-data-waers    = 'BRL'.
  <fs_sales>-data-kalks    = '1'.
  <fs_sales>-data-lprio    = '3'.
  <fs_sales>-data-vwerk    = '1102'.
  <fs_sales>-data-vsbed    = '01'.
  <fs_sales>-data-inco1    = 'CIF'.
  <fs_sales>-data-inco2    = 'CORREIOS'.
  <fs_sales>-data-zterm    = 'D000'.
  <fs_sales>-data-kkber    = 'BRCC'.
  <fs_sales>-data-ktgrd    = '01'.
  <fs_sales>-data-kabss    = '0000'.
  <fs_sales>-data-awahr    = '100'.
  <fs_sales>-data-bokre    = abap_true.
  <fs_sales>-data-prfre    = abap_true.
  <fs_sales>-data-mrnkz    = abap_true.
  <fs_sales>-datax-bzirk   = abap_true.
  <fs_sales>-datax-vkbur   = abap_true.
  <fs_sales>-datax-waers   = abap_true.
  <fs_sales>-datax-kalks   = abap_true.
  <fs_sales>-datax-lprio   = abap_true.
  <fs_sales>-datax-vwerk   = abap_true.
  <fs_sales>-datax-vsbed   = abap_true.
  <fs_sales>-datax-inco1   = abap_true.
  <fs_sales>-datax-inco2   = abap_true.
  <fs_sales>-datax-zterm   = abap_true.
  <fs_sales>-datax-kkber   = abap_true.
  <fs_sales>-datax-ktgrd   = abap_true.
  <fs_sales>-datax-kabss   = abap_true.
  <fs_sales>-datax-awahr   = abap_true.
  <fs_sales>-datax-bokre   = abap_true.
  <fs_sales>-datax-prfre   = abap_true.
  <fs_sales>-datax-mrnkz   = abap_true.

  "Le funcoes
  SELECT DISTINCT parvw
    FROM tpaer
    INTO TABLE @DATA(lt_parvw)
    WHERE pargr = 'CUST'
      AND papfl = @abap_true.
  IF sy-subrc IS INITIAL.
    <fs_sales>-functions-current_state = abap_true.

    "Preenche funcoes
    LOOP AT lt_parvw[] ASSIGNING FIELD-SYMBOL(<fs_parvw>).
      APPEND INITIAL LINE TO <fs_sales>-functions-functions[] ASSIGNING FIELD-SYMBOL(<fs_func>).
      <fs_func>-data_key-parvw = <fs_parvw>.
      <fs_func>-data-partner  = p_partnerno.
      <fs_func>-data-defpa    = abap_true.
      <fs_func>-datax-partner = abap_true.
      <fs_func>-datax-defpa   = abap_true.
    ENDLOOP.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_vendor_roles
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_vendor_roles USING p_partnerno TYPE bu_partner
                      CHANGING c_roles     TYPE bus_ei_roles.

  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM but100
      WHERE partner = p_partnerno
        AND rltyp   = 'FLVN01'.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_roles-current_state = abap_true.

    "Insere role FLVN01 - Fornecedor
    APPEND INITIAL LINE TO c_roles-roles[] ASSIGNING FIELD-SYMBOL(<fs_flcu00>).
    <fs_flcu00>-task = 'I'. "Insert
    <fs_flcu00>-currently_valid = abap_true.
    <fs_flcu00>-data_key = 'FLVN01'.
    <fs_flcu00>-data-rolecategory = 'FLVN01'.
    <fs_flcu00>-data-valid_from   = '18000101'.
    <fs_flcu00>-data-valid_to     = '99991231'.
    <fs_flcu00>-datax-valid_from  = abap_true.
    <fs_flcu00>-datax-valid_to    = abap_true.
  ENDIF.

  IF p_partnerno IS NOT INITIAL.
    SELECT COUNT(*) FROM but100
      WHERE partner = p_partnerno
        AND rltyp   = 'FLVN00'.
  ENDIF.
  IF sy-subrc <> 0 OR p_partnerno IS INITIAL.
    c_roles-current_state = abap_true.

    "Insere role FLVN00 - Fornecedor (contab.financ.)
    APPEND INITIAL LINE TO c_roles-roles[] ASSIGNING FIELD-SYMBOL(<fs_flcu01>).
    <fs_flcu01>-task = 'I'. "Insert
    <fs_flcu01>-currently_valid = abap_true.
    <fs_flcu01>-data_key = 'FLVN00'.
    <fs_flcu01>-data-rolecategory = 'FLVN00'.
    <fs_flcu01>-data-valid_from   = '18000101'.
    <fs_flcu01>-data-valid_to     = '99991231'.
    <fs_flcu01>-datax-valid_from  = abap_true.
    <fs_flcu01>-datax-valid_to    = abap_true.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_vendor_company
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_vendor_company USING p_partnerno TYPE bu_partner
                        CHANGING c_company   TYPE vmds_ei_vmd_company.

  c_company-current_state = abap_true.

  "Preenche empresa
  APPEND INITIAL LINE TO c_company-company[] ASSIGNING FIELD-SYMBOL(<fs_company>).
  <fs_company>-task = 'M'.
  <fs_company>-data_key-bukrs = 'BR11'.
  <fs_company>-data-frgrp  = 'F023'.
  <fs_company>-data-akont  = '0021101001'.
  <fs_company>-data-fdgrv  = 'C001'.
  <fs_company>-data-vzskz  = 'Z1'.
  <fs_company>-data-zterm  = 'D000'.
  <fs_company>-data-zwels  = 'F'.
  <fs_company>-data-hbkid  = '75501'.
  <fs_company>-datax-frgrp = abap_true.
  <fs_company>-datax-akont = abap_true.
  <fs_company>-datax-fdgrv = abap_true.
  <fs_company>-datax-vzskz = abap_true.
  <fs_company>-datax-zterm = abap_true.
  <fs_company>-datax-zwels = abap_true.
  <fs_company>-datax-hbkid = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& FORM f_fill_vendor_purchasing
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM f_fill_vendor_purchasing USING p_partnerno   TYPE bu_partner
                           CHANGING cs_purchasing TYPE vmds_ei_vmd_purchasing.

  cs_purchasing-current_state = abap_true.

  "Preenche org. compras
  APPEND INITIAL LINE TO cs_purchasing-purchasing[] ASSIGNING FIELD-SYMBOL(<fs_purchasing>).
  <fs_purchasing>-data_key-ekorg = 'BR11'.
  <fs_purchasing>-data-waers    = 'BRL'.
  <fs_purchasing>-data-vsbed    = '01'.
  <fs_purchasing>-data-inco1    = 'CIF'.
  <fs_purchasing>-data-inco2    = 'CORREIOS'.
  <fs_purchasing>-data-inco2_l  = <fs_purchasing>-data-inco2.
  <fs_purchasing>-data-zterm    = 'D000'.
  <fs_purchasing>-data-prfre    = abap_true.
  <fs_purchasing>-datax-waers   = abap_true.
  <fs_purchasing>-datax-vsbed   = abap_true.
  <fs_purchasing>-datax-inco1   = abap_true.
  <fs_purchasing>-datax-inco2   = abap_true.
  <fs_purchasing>-datax-inco2_l = abap_true.
  <fs_purchasing>-datax-zterm   = abap_true.
  <fs_purchasing>-datax-prfre   = abap_true.

  "Le funcoes
  SELECT DISTINCT parvw
    FROM tpaer
    INTO TABLE @DATA(lt_parvw)
    WHERE pargr = 'SUPL'
      AND papfl = @abap_true.
  IF sy-subrc IS INITIAL.
    <fs_purchasing>-functions-current_state = abap_true.

    "Preenche funcoes
    LOOP AT lt_parvw[] ASSIGNING FIELD-SYMBOL(<fs_parvw>).
      APPEND INITIAL LINE TO <fs_purchasing>-functions-functions[] ASSIGNING FIELD-SYMBOL(<fs_func>).
      <fs_func>-data_key-parvw = <fs_parvw>.
      <fs_func>-data-partner  = p_partnerno.
      <fs_func>-data-defpa    = abap_true.
      <fs_func>-datax-partner = abap_true.
      <fs_func>-datax-defpa   = abap_true.
    ENDLOOP.

  ENDIF.

ENDFORM.