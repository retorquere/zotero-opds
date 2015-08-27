###
 * Ice Cold Apps
 * 
 * GENERAL SETTINGS
 *
 * Warning: if you have problems to read, create or edit files/folder try to change the permissions to a higher octal number. This normally solves the problems.
 *
###

class ICASync
  constructor: (@query) ->

  serve: ->
    return @["_#{@query.action}"].call(@)

        case "download":
            if(!$current_user->permissions->allow_read || !$current_user->permissions->allow_download) { mssgError("permission", "Permission error"); exit(); }
            doDownloadFile(get_received_variable("from"));
            break;
        case "upload":
            if(!$current_user->permissions->allow_write || !$current_user->permissions->allow_upload) { mssgError("permission", "Permission error"); exit(); }
            doUploadFile();
            break;
        case "deletefile":
            if(!$current_user->permissions->allow_write || !$current_user->permissions->allow_delete) { mssgError("permission", "Permission error"); exit(); }
            doDeleteFile(get_received_variable("from"));
            break;
        case "deletedir":
            if(!$current_user->permissions->allow_write || !$current_user->permissions->allow_delete) { mssgError("permission", "Permission error"); exit(); }
            doDeleteDir(get_received_variable("from"));
            break;
        case "copyfile":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doCopyFile(get_received_variable("from"), get_received_variable("to"));
            break;
        case "copydir":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doCopyDir(get_received_variable("from"), get_received_variable("to"));
            break;
        case "renamefile":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doRenameFile(get_received_variable("from"), get_received_variable("to"));
            break;
        case "renamedir":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doRenameDir(get_received_variable("from"), get_received_variable("to"));
            break;
        case "createdir":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doCreateDir(get_received_variable("from"));
            break;
        case "existsfile":
            doExistsFile(get_received_variable("from"));
            break;
        case "existsdir":
            doExistsDir(get_received_variable("from"));
            break;
        case "serverinformation":
            if(!$current_user->permissions->allow_read || !$current_user->permissions->allow_serverinformation) { mssgError("permission", "Permission error"); exit(); }
            serverInformation();
            break;
        case "chgrp":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doChgrp(get_received_variable("from"), get_received_variable("id"));
            break;
        case "chown":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doChown(get_received_variable("from"), get_received_variable("id"));
            break;
        case "chmod":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doChmod(get_received_variable("from"), get_received_variable("id"));
            break;
        case "clearstatcache":
            doClearstatcache();
            break;
        case "lchgrp":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doLchgrp(get_received_variable("from"), get_received_variable("id"));
            break;
        case "lchown":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doLchown(get_received_variable("from"), get_received_variable("id"));
            break;
        case "link":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doLink(get_received_variable("from"), get_received_variable("link"));
            break;
        case "symlink":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doSymlink(get_received_variable("from"), get_received_variable("link"));
            break;
        case "touch":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doTouch(get_received_variable("from"), get_received_variable("time"), get_received_variable("atime"));
            break;
        case "umask":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doUmask(get_received_variable("from"), get_received_variable("id"));
            break;
        case "unlink":
            if(!$current_user->permissions->allow_write) { mssgError("permission", "Permission error"); exit(); }
            doUnlink(get_received_variable("from"));
            break;
        case "server2server":
            if(!$current_user->permissions->allow_server2server) { mssgError("permission", "Permission error"); exit(); }
            doServer2Server();
            break;
    }
    
    return;
    
    # general information
  _generalinformation: ->
    data_return = {}
      
    data_return.version = "1.0.2"
    data_return.version_code = 2
    
    # data_return['phpversion'] = @phpversion();

    data_return.functions_available = {}
    for k of @
      continue unless k[0] == '_'
      data_return.functions_available[k.slice(1)] = true

    data_return.status = "ok"

    return JSON.stringify(data_return)
    
  listfiles: ->
    if !@query.path
      # user library
    else
      # compute location from path

    # if path doesn't exist, throw error
    
    all_files = []
    counter = 0;
    $handler = @opendir($_path);
    while($file = @readdir($handler)) {
      # checks
      if(($file == ".") || ($file == "..")) {
        continue;
      }
      $full_path = convertPathFile(get_absolute_path($_path.DIRECTORY_SEPARATOR.$file));
      if($full_path == convertPathFile(__FILE__)) {
        continue;
      }
      $docontinue = false;
      foreach($config_files_exclude as $file_exclude) {
        if(isBaseDir($file_exclude) && startsWith($full_path, $file_exclude)) {
          $docontinue = true;
        } else if(!isBaseDir($file_exclude) && (strpos($file_exclude,DIRECTORY_SEPARATOR) !== true) && ($file == $file_exclude)) {
          $docontinue = true;
        } else if(!isBaseDir($file_exclude) && (strpos($file_exclude,DIRECTORY_SEPARATOR) !== false) && startsWith($_path, DIRECTORY_SEPARATOR.$file_exclude)) {
          $docontinue = true;
        }
      }
      if($docontinue) {
        continue;
      }
      
      # get file info
      $file_data = array();
      $file_data['filename'] = $file;
      $file_data['path'] = $full_path;
      if(function_exists('realpath')) { $file_data['realpath'] = realpath($full_path); }
      
      if(function_exists('fileatime')) { $file_data['fileatime'] = @fileatime($full_path); }
      if(function_exists('filectime')) { $file_data['filectime'] = @filectime($full_path); }
      if(function_exists('fileinode')) { $file_data['fileinode'] = @fileinode($full_path); }
      if(function_exists('filemtime')) { $file_data['filemtime'] = @filemtime($full_path); }
      
      if(function_exists('fileperms'))  {
        $file_data['fileperms'] = @fileperms($full_path);
        $file_data['fileperms_octal'] = @substr(sprintf('%o', @fileperms($full_path)), -4);
        $file_data['fileperms_readable'] = get_readable_permission(@fileperms($full_path));
      }
      
      if(function_exists('filesize')) { 
        $file_data['filesize'] = @filesize($full_path);
        if(function_exists('is_file') && @is_file($full_path)) {
          if(@filesize($full_path) < (1024 * 1024 * 10)) {
            $file_data['md5_file'] = @md5_file($full_path);
            $file_data['sha1_file'] = @sha1_file($full_path);
          } 
        }
      }
      if(function_exists('filetype')) { $file_data['filetype'] = @filetype($full_path); }
      
      if(function_exists('is_dir')) { $file_data['is_dir'] = @is_dir($full_path); }
      if(function_exists('is_executable')) { $file_data['is_executable'] = @is_executable($full_path); }
      if(function_exists('is_file')) { $file_data['is_file'] = @is_file($full_path); }
      if(function_exists('is_link')) { $file_data['is_link'] = @is_link($full_path); }
      if(function_exists('is_readable')) { $file_data['is_readable'] = @is_readable($full_path); }
      if(function_exists('is_uploaded_file')) { $file_data['is_uploaded_file'] = @is_uploaded_file($full_path); }
      if(function_exists('is_writable')) { $file_data['is_writable'] = @is_writable($full_path); }
      
      if(function_exists('linkinfo')) { $file_data['linkinfo'] = @linkinfo($full_path); }
      if(function_exists('readlink')) { 
        $link_path = @readlink($full_path);
        if(function_exists('is_dir') && @is_dir($full_path)) { 
          $link_path = convertPathDir($link_path);
        } else if(function_exists('is_file') && @is_file($full_path)) { 
          $link_path = convertPathFile($link_path);
        } else {
          $link_path = convertPathStartSlash($link_path);
        }
        if(startsWith($link_path, getBaseDir())) {
          $link_path = @substr($link_path, @strlen(getBaseDir()));
        }
        $link_path = convertPathStartSlash($link_path);
        $file_data['readlink'] = $link_path;
      }
      
      if(function_exists('stat'))  {
        $stat = @stat($full_path);
        $file_data['stat_data'] = $stat;
      }
      
      if(function_exists('filegroup')) { 
        $file_data['filegroup'] = @filegroup($full_path);
        if(function_exists('posix_getgrgid'))  {
          $filegroup = @posix_getgrgid(@filegroup($full_path));
          $file_data['filegroup_data'] = $filegroup;
        }
      }
      
      if(function_exists('fileowner')) { 
        $file_data['fileowner'] = @fileowner($full_path);
        if(function_exists('posix_getpwuid'))  {
          $fileowner = @posix_getpwuid(@fileowner($full_path));
          $file_data['fileowner_data'] = $fileowner;
        }
      }
      
      
      $counter++;
      $all_files[] = $file_data;
    
    }
    
    @closedir($handler);
    
    $data_return = array();
    $data_return['data'] = $all_files;
    $data_return['counter'] = $counter;
    $data_return['path'] = $_path;
    $data_return['status'] = "ok";
    
    # var_dump($return_files);
    echo @json_encode($data_return);
  }
  
  # download
  function doDownloadFile($from) {
    $from = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    @readfile($from);
  }
  
  
  # upload
  function doUploadFile() {
  
    $to = get_received_variable("to");
    $time_lastmodified = get_received_variable("time_lastmodified");
    $time_accessed = get_received_variable("time_accessed");
    $chmod = get_received_variable("chmod");
    $chown = get_received_variable("chown");
    $chgrp = get_received_variable("chgrp");
  
    $to = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$to));
    if(@move_uploaded_file($_FILES['filename1']['tmp_name'], $to)) {
      
      if(function_exists('touch') && (($time_lastmodified != "") || ($time_accessed != ""))) {
        if($time_accessed == "") {
          @touch($to, $time_lastmodified);
        } else {
          @touch($to, $time_lastmodified, $time_accessed);
        }
      }
      if(function_exists('chmod') && ($chmod != "")) {
        @chmod($to, octdec($chmod));
      }
      if(function_exists('chown') && ($chown != "")) {
        @chown($to, $chown);
      }
      if(function_exists('chgrp') && ($chgrp != "")) {
        @chgrp($to, $chgrp);
      }
      
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  
  # delete
  function doDeleteFile($from) {
    $from = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@unlink($from)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  function doDeleteDir($from) {
    $from = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    rmdir_recursive($from);
    
    mssgOk("done", "Done");
  }
  
  # copy
  function doCopyFile($from, $to) {
  
    $from = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $to = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$to));
    if(@copy($from, $to)) {
      set_same_times($from, $to);
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  function doCopyDir($from, $to) {
  
    $from = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $to = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$to));
    
    recurse_copy($from, $to);
    
    mssgOk("done", "Done");
  }
  
  # rename
  function doRenameFile($from, $to) {
  
    $from = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $to = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$to));
    if(@rename($from, $to)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  function doRenameDir($from, $to) {
  
    $from = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $to = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$to));
    if(@rename($from, $to)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # create dir
  function doCreateDir($from) {
    $from = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@mkdir($from, 0777, true)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # exists
  function doExistsFile($from) {
    $from = convertPathFile(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@file_exists($from)) {
      mssgOk("exists", "Exists");
    } else {
      mssgOk("notexists", "Not exists");
    }
  }
  function doExistsDir($from) {
    $from = convertPathDir(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@file_exists($from)) {
      mssgOk("exists", "Exists");
    } else {
      mssgOk("notexists", "Not exists");
    }
  }
  
  # server information
  function serverInformation() {
    global $config, $current_user, $_SERVER, $_GET, $_POST, $_SESSION, $_ENV, $_FILES, $_COOKIE;
    $data_return = array();
    if(function_exists('disk_free_space')) { $data_return['disk_free_space'] = @disk_free_space(getBaseDir()); }
    if(function_exists('disk_total_space')) { $data_return['disk_total_space'] = @disk_total_space(getBaseDir()); }
    $data_return['basedir'] = getBaseDir();
    
    if(function_exists('phpversion')) { $data_return['phpversion'] = @phpversion(); }
    if(function_exists('curl_version')) { $data_return['curl_version'] = @curl_version(); }
    
    if(function_exists('sys_getloadavg')) {
      $data_return['sys_getloadavg'] = @sys_getloadavg();
    }
    
    $data_return['config'] = $config;
    $data_return['current_user'] = $current_user;
    
    $data_return['status'] = "ok";
    
    $data_return['phpinfo'] = phpinfo_array(true);
    
    $data_return['_SERVER'] = @$_SERVER;
    $data_return['_GET'] = @$_GET;
    $_POST['password'] = "*";
    $data_return['_POST'] = @$_POST;
    $data_return['_SESSION'] = @$_SESSION;
    $data_return['_ENV'] = @$_ENV;
    # $data_return['_FILES'] = @$_FILES;
    # $data_return['_COOKIE'] = @$_COOKIE;
    
    echo @json_encode($data_return);
  }
  
  # chgrp
  function doChgrp($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@chgrp($from, $id)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # chmod
  function doChmod($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@chmod($from, octdec($id))) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # chown
  function doChown($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@chown($from, $id)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # clearstatcache
  function doClearstatcache() {
    @clearstatcache();
    
    mssgOk("done", "Done");
  }
  
  # lchgrp
  function doLchgrp($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@lchgrp($from, $id)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # lchown
  function doLchown($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@lchown($from, $id)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # link
  function doLink($from, $link) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $link = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$link));
    if(@link($from, $link)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # symlink
  function doSymlink($from, $link) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $link = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$link));
    if(@symlink($from, $link)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  # touch
  function doTouch($from, $time, $atime) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if($atime == "") {
      if(@touch($from, $time)) {
        mssgOk("done", "Done");
      } else {
        mssgError("error", "Error");
      }
    } else {
      if(@touch($from, $time, $atime)) {
        mssgOk("done", "Done");
      } else {
        mssgError("error", "Error");
      }
    }
  }
  
  # umask
  function doUmask($from, $id) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    $umaskT = @umask($from, $id);
    mssgOk($umaskT, "Done");
  }
  
  
  # unlink
  function doUnlink($from) {
    $from = convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.$from));
    if(@unlink($from)) {
      mssgOk("done", "Done");
    } else {
      mssgError("error", "Error");
    }
  }
  
  
  # server 2 server
  function doServer2Server() {
  
    # get_token1
    # token1
    # token2
    # username
    # password
    # htpasswd
    # htpasswd username
    # htpasswd password
    # from
    # to
    
    $target_url = get_received_variable("dest_url");
  
  	$array_post = array(
  	'token1' => get_received_variable("dest_token1"),
  	'token2' => get_received_variable("dest_token2"),
  	'username' => get_received_variable("dest_username"),
  	'password' => get_received_variable("dest_password"),
  	'action' => get_received_variable("dest_action"),
  	'from' => get_received_variable("dest_from"),
  	'to' => get_received_variable("dest_to"),
  	'path' => get_received_variable("dest_path"),
  	'time_lastmodified' => get_received_variable("dest_time_lastmodified"),
  	'time_accessed' => get_received_variable("dest_time_accessed"),
  	'chmod' => get_received_variable("dest_chmod"),
  	'chown' => get_received_variable("dest_chown"),
  	'chgrp' => get_received_variable("dest_chgrp"),
  	'id' => get_received_variable("dest_id"),
  	'link' => get_received_variable("dest_link"),
  	'time' => get_received_variable("dest_time"),
  	'atime' => get_received_variable("dest_atime")
  	);
  	
  	if(get_received_variable("dest_action") == "upload") {
      $array_post_add1 = array(
      'filename1'=>'@'.convertPathStartSlash(get_absolute_path(getBaseDir().DIRECTORY_SEPARATOR.get_received_variable("from")))
      );
      $array_post = array_merge($array_post, $array_post_add1);
  	}
   
    $_curl = curl_init();
  	curl_setopt($_curl, CURLOPT_URL, $target_url);
  	curl_setopt($_curl, CURLOPT_POST, 1);
  	curl_setopt($_curl, CURLOPT_POSTFIELDS, $array_post);
  	if(get_received_variable("dest_httpauth") != "") {
      curl_setopt($_curl, CURLOPT_USERPWD, get_received_variable("dest_httpauth_username").":".get_received_variable("dest_httpauth_password"));  
  	}
    # curl_setopt($_curl, CURLOPT_RETURNTRANSFER, 1);
  	# $result = curl_exec($_curl);
  	curl_exec($_curl);
  	curl_close($_curl);
  
    # echo $result;
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  function mssgOk($_id, $_message) {
    $data_return = array();
    
    $data_return['status'] = "ok";
    $data_return['id'] = $_id;
    $data_return['message'] = $_message;
    
    echo @json_encode($data_return);
  }
  function mssgError($_id, $_message) {
    $data_return = array();
    
    $data_return['status'] = "error";
    $data_return['id'] = $_id;
    $data_return['message'] = $_message;
    
    echo @json_encode($data_return);
  }
  
  
  
  
  
  
  
  
  
  ###
  * OTHER
  ###
  
  function is_dir_allowed($_path) {
    global $config, $current_user;
    
    # if(!$current_user->path_forcestay) {
    #   return true;
    # } 
    
    $temp_basedir = convertPathDir($_path);
    
    if(startsWith($temp_basedir, getBaseDir())) {
      return true;
    }
    return false;  
  }
  
  
  function getBaseDir() {
    global $config, $current_user;
    $return_path = DIRECTORY_SEPARATOR;
    if(@is_empty($config['path_default'])) {
      $return_path = pathinfo(__FILE__, PATHINFO_DIRNAME);
    } else {
      if(isBaseDir($config['path_default'])) {
        $return_path = $config['path_default'];
      } else {
        $return_path = pathinfo(__FILE__, PATHINFO_DIRNAME).DIRECTORY_SEPARATOR.$config['path_default'];
      }
    }
    if(!@is_empty($current_user->path_default)) {
      if(isBaseDir($current_user->path_default)) {
        $return_path = $current_user->path_default;
      } else {
        $return_path = $return_path.DIRECTORY_SEPARATOR.$current_user->path_default;
      }
    }
    $return_path = get_absolute_path($return_path);
    return convertPathDir($return_path);
  }
  
  function isBaseDir($_path) {
    if(!base_with_slash()) {
      if(strpos($_path,':') !== false) {
        return true;
      } else {
        return false;
      }
    } else {
      if(startsWith($_path, DIRECTORY_SEPARATOR)) {
        return true;
      } else {
        return false;
      }
    }
  }
  
  function convertPathDir($_path) {
    if(!endsWith($_path, DIRECTORY_SEPARATOR)) {
      $_path = $_path.DIRECTORY_SEPARATOR;
    }
    if(base_with_slash()) {
      if(!startsWith($_path, DIRECTORY_SEPARATOR)) {
        $_path = DIRECTORY_SEPARATOR.$_path;
      }
    }
    return $_path;
  }
  
  function convertPathFile($_path) {
    if(endsWith($_path, DIRECTORY_SEPARATOR)) {
      $_path = substr($_path, 0, -1);
    }
    if(base_with_slash()) {
      if(!startsWith($_path, DIRECTORY_SEPARATOR)) {
        $_path = DIRECTORY_SEPARATOR.$_path;
      }
    }
    return $_path;
  }
  
  function convertPathStartSlash($_path) {
    if(base_with_slash()) {
      if(!startsWith($_path, DIRECTORY_SEPARATOR)) {
        $_path = DIRECTORY_SEPARATOR.$_path;
      }
    }
    return $_path;
  }
  
  function base_with_slash() {
    if(startsWith(__FILE__, DIRECTORY_SEPARATOR)) {
      return true;
    } else {
      return false;
    }
  }
  
  function is_empty($_variable) {
    if(($_variable == null) || (empty($_variable)) || ($_variable = "")) {
      return true;
    }
    return false;
  }
  
  function get_received_variable($_variable) {
    global $config, $_POST, $_GET;
    # if($config['variables_post']) {
      return $_POST[$_variable];
    # } else {
    #   return $_GET[$_variable];
    # }
  }
  
  function startsWith($haystack, $needle){
      return $needle === "" || @strpos($haystack, $needle) === 0;
  }
  function endsWith($haystack, $needle){
      return $needle === "" || @substr($haystack, -@strlen($needle)) === $needle;
  }
  
  
  function get_absolute_path($path) {
      $path = @str_replace(array('/', '\\'), DIRECTORY_SEPARATOR, $path);
      $parts = @array_filter(@explode(DIRECTORY_SEPARATOR, $path), 'strlen');
      $absolutes = array();
      foreach ($parts as $part) {
          if ('.' == $part) continue;
          if ('..' == $part) {
              @array_pop($absolutes);
          } else {
              $absolutes[] = $part;
          }
      }
      return @implode(DIRECTORY_SEPARATOR, $absolutes);
  }
  
  function get_client_ip() {
    global $_SERVER;
   $ipaddress = '';
   if ($_SERVER['HTTP_CLIENT_IP']) {
       $ipaddress = $_SERVER['HTTP_CLIENT_IP'];
   } else if($_SERVER['HTTP_X_FORWARDED_FOR']) {
       $ipaddress = $_SERVER['HTTP_X_FORWARDED_FOR'];
   } else if($_SERVER['HTTP_X_FORWARDED']) {
       $ipaddress = $_SERVER['HTTP_X_FORWARDED'];
   } else if($_SERVER['HTTP_FORWARDED_FOR']) {
       $ipaddress = $_SERVER['HTTP_FORWARDED_FOR'];
   } else if($_SERVER['HTTP_FORWARDED']) {
       $ipaddress = $_SERVER['HTTP_FORWARDED'];
   } else if($_SERVER['REMOTE_ADDR']) {
       $ipaddress = $_SERVER['REMOTE_ADDR'];
   } else {
       $ipaddress = 'UNKNOWN';
   }
   return $ipaddress; 
  }
  
  function get_readable_permission($perms) {
    if (($perms & 0xC000) == 0xC000) {
        #  Socket
        $info = 's';
    } elseif (($perms & 0xA000) == 0xA000) {
        #  Symbolic Link
        $info = 'l';
    } elseif (($perms & 0x8000) == 0x8000) {
        #  Regular
        $info = '-';
    } elseif (($perms & 0x6000) == 0x6000) {
        #  Block special
        $info = 'b';
    } elseif (($perms & 0x4000) == 0x4000) {
        #  Directory
        $info = 'd';
    } elseif (($perms & 0x2000) == 0x2000) {
        #  Character special
        $info = 'c';
    } elseif (($perms & 0x1000) == 0x1000) {
        #  FIFO pipe
        $info = 'p';
    } else {
        #  Unknown
        $info = 'u';
    }
  
    $info .= (($perms & 0x0100) ? 'r' : '-');
    $info .= (($perms & 0x0080) ? 'w' : '-');
    $info .= (($perms & 0x0040) ?
                (($perms & 0x0800) ? 's' : 'x' ) :
                (($perms & 0x0800) ? 'S' : '-'));
  
    $info .= (($perms & 0x0020) ? 'r' : '-');
    $info .= (($perms & 0x0010) ? 'w' : '-');
    $info .= (($perms & 0x0008) ?
                (($perms & 0x0400) ? 's' : 'x' ) :
                (($perms & 0x0400) ? 'S' : '-'));
  
    $info .= (($perms & 0x0004) ? 'r' : '-');
    $info .= (($perms & 0x0002) ? 'w' : '-');
    $info .= (($perms & 0x0001) ?
                (($perms & 0x0200) ? 't' : 'x' ) :
                (($perms & 0x0200) ? 'T' : '-'));
  
    return $info;
  }
  
  function set_same_times($from, $to) {
    if(function_exists('touch')) {
      if(function_exists('filemtime') && function_exists('fileatime')) {
        @touch($to, @filemtime($from), @fileatime($from));
      } else if(function_exists('filemtime')) {
        @touch($to, @filemtime($from));
      }
    }
  }
  
  function recurse_copy($src,$dst) { 
      $dir = @opendir($src); 
      @mkdir($dst); 
      set_same_times($src, $dst);
      while(false !== ( $file = @readdir($dir)) ) { 
          if (( $file != '.' ) && ( $file != '..' )) { 
              if ( @is_dir($src .DIRECTORY_SEPARATOR. $file) ) { 
                  recurse_copy($src .DIRECTORY_SEPARATOR. $file, $dst .DIRECTORY_SEPARATOR. $file); 
              } else { 
                  @copy($src.DIRECTORY_SEPARATOR.$file, $dst.DIRECTORY_SEPARATOR.$file); 
                  set_same_times($src.DIRECTORY_SEPARATOR.$file, $dst.DIRECTORY_SEPARATOR.$file);
              } 
          } 
      } 
      @closedir($dir); 
  } 
  function rmdir_recursive($dir) {
      foreach(scandir($dir) as $file) {
          if ('.' === $file || '..' === $file) continue;
          if (@is_dir($dir.DIRECTORY_SEPARATOR.$file)) rmdir_recursive($dir.DIRECTORY_SEPARATOR.$file);
          else @unlink($dir.DIRECTORY_SEPARATOR.$file);
      }
      @rmdir($dir);
  }
  
  function phpinfo_array($return=false){
   @ob_start();
   @phpinfo(-1);
   
   $pi = @preg_replace(
   array('#^.*<body>(.*)</body>.*$#ms', '#<h2>PHP License</h2>.*$#ms',
   '#<h1>Configuration</h1>#',  "#\r?\n#", "#</(h1|h2|h3|tr)>#", '# +<#',
   "#[ \t]+#", '#&nbsp;#', '#  +#', '# class=".*?"#', '%&#039;%',
    '#<tr>(?:.*?)" src="(?:.*?)=(.*?)" alt="PHP Logo" /></a>'
    .'<h1>PHP Version (.*?)</h1>(?:\n+?)</td></tr>#',
    '#<h1><a href="(?:.*?)\?=(.*?)">PHP Credits</a></h1>#',
    '#<tr>(?:.*?)" src="(?:.*?)=(.*?)"(?:.*?)Zend Engine (.*?),(?:.*?)</tr>#',
    "# +#", '#<tr>#', '#</tr>#'),
   array('$1', '', '', '', '</$1>' . "\n", '<', ' ', ' ', ' ', '', ' ',
    '<h2>PHP Configuration</h2>'."\n".'<tr><td>PHP Version</td><td>$2</td></tr>'.
    "\n".'<tr><td>PHP Egg</td><td>$1</td></tr>',
    '<tr><td>PHP Credits Egg</td><td>$1</td></tr>',
    '<tr><td>Zend Engine</td><td>$2</td></tr>' . "\n" .
    '<tr><td>Zend Egg</td><td>$1</td></tr>', ' ', '%S%', '%E%'),
   @ob_get_clean());
  
   $sections = @explode('<h2>', @strip_tags($pi, '<h2><th><td>'));
   unset($sections[0]);
  
   $pi = array();
   foreach($sections as $section){
     $n = @substr($section, 0, @strpos($section, '</h2>'));
     @preg_match_all(
     '#%S%(?:<td>(.*?)</td>)?(?:<td>(.*?)</td>)?(?:<td>(.*?)</td>)?%E%#',
       $section, $askapache, PREG_SET_ORDER);
     foreach($askapache as $m)
         $pi[$n][$m[1]]=(!isset($m[3])||$m[2]==$m[3])?$m[2]:@array_slice($m,2);
   }
  
   return ($return === false) ? @print_r($pi) : $pi;
  }
  
  
  ###
  * DATA
  ###
  class User {
    public $anonymous = false;
    public $username = "";
    public $password = "";
    public $path_default = "";
    public $permissions;
    public function __construct($anonymousT, $usernameT, $passwordT, $path_defaultT, $permissionsT) {
      $this->anonymous = $anonymousT;
      $this->username = $usernameT;
      $this->password = $passwordT;
      $this->path_default = $path_defaultT;
      $this->permissions = $permissionsT;
    }  
  }
  class Permissions {
    public $allow_read = true;
    public $allow_write = true;
    public $allow_delete = true;
    public $allow_download = true;
    public $allow_upload = true;
    public $allow_serverinformation = true;
    public $allow_server2server = true;
    public function __construct($allow_readT, $allow_writeT, $allow_deleteT, $allow_downloadT, $allow_uploadT, $allow_serverinformationT, $allow_server2serverT) {
      $this->allow_read = $allow_readT;
      $this->allow_write = $allow_writeT;
      $this->allow_delete = $allow_deleteT;
      $this->allow_download = $allow_downloadT;
      $this->allow_upload = $allow_uploadT;
      $this->allow_serverinformation = $allow_serverinformationT;
      $this->allow_server2server = $allow_server2serverT;
    }
  }
  
  
  ?>
