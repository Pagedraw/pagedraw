## Single source of truth for our pagedraw.json recommendations

exports.recommended_pagedraw_json_for_app_id = (app_id, filepath_prefix) ->
   """
   {"app": "#{app_id}", "managed_folders": ["#{if filepath_prefix.endsWith('/') then filepath_prefix else filepath_prefix + '/'}"] }
   """
