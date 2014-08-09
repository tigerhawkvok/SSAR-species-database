<?php

/***
 * SSAR Common names database API target
 ***/

/*****************
 * Setup
 *****************/

require_once(dirname(__FILE__)."/db/DBHelper.php");

$db = new DBHelper();
$db->setSQLUser($default_sql_user);
$db->setDB($default_database);
$db->setSQLPW($default_sql_password);
$db->setSQLURL($sql_url);
$db->setCols($db_cols);
$db->setTable($default_table);

if(isset($_SERVER['QUERY_STRING'])) parse_str($_SERVER['QUERY_STRING'],$_GET);

$start_script_timer = microtime_float();

if(!function_exists('elapsed'))
  {
    function elapsed($start_time = null)
    {
      /***
       * Return the duration since the start time in
       * milliseconds.
       * If no start time is provided, it'll try to use the global
       * variable $start_script_timer
       *
       * @param float $start_time in unix epoch. See http://us1.php.net/microtime
       ***/

      if(!is_numeric($start_time))
        {
          global $start_script_timer;          
          if(is_numeric($start_script_timer)) $start_time = $start_script_timer;
          else return false;
        }      
      return 1000*(microtime_float() - (float)$start_time);
    }
  }

function returnAjax($data)
{
  if(!is_array($data)) $data=array($data);
  $data["execution_time"] = elapsed();
  header('Cache-Control: no-cache, must-revalidate');
  header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
  header('Content-type: application/json');
  print json_encode($data,JSON_FORCE_OBJECT);
  exit();
}


/*****************************
 * Modes the API will accept
 *****************************/




/*****************************
 * The actual handlers
 *****************************/



?>