*&---------------------------------------------------------------------*
*& Report ZZIP
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zzip.
TYPES: BEGIN OF bin_file,                          " Typ für Binärdatei mit Meta-Infos für das Zipfile
         name TYPE string,
         size TYPE i,
         data TYPE solix_tab,
       END OF bin_file.

DATA: lv_filename TYPE string.                     " Dateiname für FileOpen/FileSave
DATA: wa_file TYPE bin_file.                       " Binärdatei mit Meta-Infos für das Zipfile
DATA: it_binfiles TYPE STANDARD TABLE OF bin_file. " unkomprimierter Stream (Tabelle mit Dateien zum Zippen)
DATA: lv_path TYPE string.

START-OF-SELECTION.
* ZIP-Objekt erzeugen
  DATA(o_zip) = NEW cl_abap_zip( ).

  DATA: it_sel_filetab TYPE filetable.
  DATA: ret_code TYPE i.
  DATA: lv_action TYPE i.
* FileOpen-Dialog für Dateiauswahl anzeigen
* Mehrfachselektion möglich
  cl_gui_frontend_services=>file_open_dialog( EXPORTING
                                                window_title   = 'Dateien zum Komprimieren auswählen'
                                                multiselection = abap_true
                                              CHANGING
                                                file_table     = it_sel_filetab
                                                rc             = ret_code    " Anzahl ausgewählte Dateien, -1 bei Fehler
                                                user_action    = lv_action ).

  IF lv_action = cl_gui_frontend_services=>action_ok.

* Ausgewählte Dateien durchgehen
    LOOP AT it_sel_filetab INTO DATA(wa_sel_file).

      WRITE: / |Datei hinzugefügt: { wa_sel_file-filename }|.

* Dateien auf den Appl.-Server hochladen
      cl_gui_frontend_services=>gui_upload( EXPORTING
                                              filename   = |{ wa_sel_file-filename }|
                                              filetype   = 'BIN'
                                            IMPORTING
                                              filelength = wa_file-size
                                            CHANGING
                                              data_tab   = wa_file-data ).

* Pfad + Dateinamen aufsplitten
      CALL FUNCTION 'SO_SPLIT_FILE_AND_PATH'
        EXPORTING
          full_name     = wa_sel_file-filename
        IMPORTING
          file_path     = lv_path
          stripped_name = wa_file-name
        EXCEPTIONS
          x_error       = 1
          OTHERS        = 2.

* Datei zum Stream hinzufügen
      APPEND wa_file TO it_binfiles.

    ENDLOOP.

    ULINE.

    DATA: lv_xstring TYPE xstring.
* unkomprimierte Daten zum Zip-File hinzufügen
    LOOP AT it_binfiles INTO wa_file.

* jeden Datei-Stream binär zu xstring wandeln
      CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
        EXPORTING
          input_length = wa_file-size
        IMPORTING
          buffer       = lv_xstring
        TABLES
          binary_tab   = wa_file-data.

      o_zip->add( name    = wa_file-name
                  content = lv_xstring ).

    ENDLOOP.

* Daten komprimieren
    DATA(lv_zip) = o_zip->save( ).

    DATA: lv_zip_size TYPE i.
    DATA: it_zip_bin_data TYPE STANDARD TABLE OF raw255.

* xstring mit Zip-Daten zu binär rückwandeln
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = lv_zip
      IMPORTING
        output_length = lv_zip_size
      TABLES
        binary_tab    = it_zip_bin_data.

    DATA: lv_dest_filepath TYPE string.

* SaveFile-Dialog aufrufen
    cl_gui_frontend_services=>file_save_dialog( EXPORTING
                                                  window_title         = 'Zipdatei speichern'
                                                  file_filter          = '(*.zip)|*.zip|'
                                                CHANGING
                                                  filename             = lv_filename
                                                  path                 = lv_path
                                                  fullpath             = lv_dest_filepath ).

* Zipdatei vom Appl-Server auf den lokalen Pfad speichern
    cl_gui_frontend_services=>gui_download( EXPORTING
                                              filename                = lv_dest_filepath
                                              filetype                = 'BIN'
                                              bin_filesize            = lv_zip_size
                                            CHANGING
                                              data_tab                = it_zip_bin_data ).

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ELSE.
      WRITE: / |Zipdatei erfolgreich unter { lv_dest_filepath } gespeichert.|.
    ENDIF.
  ENDIF.
