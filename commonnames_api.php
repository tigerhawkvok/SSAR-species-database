<?php

/***********************************************************
 * SSAR Common names database API target
 *
 * API DESCRIPTION HERE
 *
 * API MODES HERE
 *
 *
 * Initial version by Philip Kahn
 * Started July 2014
 * https://github.com/tigerhawkvok/SSAR-species-database
 **********************************************************/

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

if(isset($_SERVER['QUERY_STRING'])) parse_str($_SERVER['QUERY_STRING'],$_REQUEST);

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

function checkColumnExists($column)
{
  if empty($column) return true;
  global $db;
  $cols = $db->getColumns();
  if(!in_array($column,$cols))
    {
      returnAjax(array("status"=>false,"error"=>"Invalid column","human_error"=>"Sorry, you specified a lookup criterion that doesn't exist. Please try again.","column"=>$column));
    }
  return true;
}

/*****************************
 * Setup flags
 *****************************/

$flag_fuzzy = boolstr($_REQUEST['fuzzy']);
$loose = boolstr($_REQUEST['loose']);
# Default limit is specified in CONFIG
$limit = is_numeric($_REQUEST['limit']) && $_REQUEST['limit'] >= 1 ? intval($_REQUEST['limit']):$default_limit;

checkColumnExists($_REQUEST['only']);
checkColumnExists($_REQUEST['include']);

$params = array();
$boolean_type = false;
if(isset($_REQUEST['filter']))
  {
    $params = smart_decode64($_REQUEST['filter']);
    if(empty($params))
      {
        $params_temp = json_decode($_REQUEST['filter'],true);
        if(!empty($params_temp))
          {
            $params = array();
            foreach($params_temp as $col=>$lookup)
              {
                $params[$db->sanitize(deEscape($col))] = $db->sanitize(deEscape($lookup));
              }
          }
      }
    if(!empty($params))
      {
        # Does the "BOOLEAN_TYPE" key exist?
        if(!array_key_exists("BOOLEAN_TYPE",$params)) returnAjax(array("status"=>false,"error"=>"Missing required parameter","human_error"=>"The key 'BOOLEAN_TYPE' must exist and be either 'AND' or 'OR'.","given"=>$params));
        # Is it valid?
        if($params['BOOLEAN_TYPE'] != "AND" || $params['BOOLEAN_TYPE'] != "OR") returnAjax(array("status"=>false,"error"=>"Missing required parameter","human_error"=>"The key 'BOOLEAN_TYPE' must exist and be either 'AND' or 'OR'.","given"=>$params));
        $boolean_type = $params['BOOLEAN_TYPE'];
        unset($params['BOOLEAN_TYPE']);
        # Do all the columns exist?
        foreach($params as $col=>$lookup)
          {
            checkColumnExists($col);
          }
      }
  }


$search = $db->sanitize(deEscape($_REQUEST['q']));



/*****************************
 * The actual handlers
 *****************************/

function areSimilar($string1,$string2,$distance=70,$depth=3)
{
  /*
   * Returns a TRUE if $string2 is similar to $string1,
   * FALSE otherwise.
   */
  # Is it a substring?
  $i=1;
  if(metaphone($string1) == metaphone($string2) && $i<=$depth ) return true;
  $i++;
  if(soundex($string1) == soundex($string2) && $i<=$depth) return true;
  $i++;
  $similar_difference = similar_text($string1,$string2,$percent);
  if($percent >= $distance && $i <=$depth) return true;
  $i++;
  $max_distance = strlen($string1)*($distance/100);
  if(levenshtein($string1,$string2) < $max_distance && $i<=$depth) return true;
  $i++;
  return false;
}

function handleParamSearch($filter_params,$extra_params = false)
{
  /***
   * Handle the searches when they're using advanced options
   *
   * @return array the result vector
   ***/
  return false;
}

/****
 * The actual main search loop
 ****/

$result_vector = array();
if(empty($params) || !empty($search))
  {
    # There was either a parsing failure, or no filter set.
    if(empty($search)) $search = "*"; # Wildcard it. Be greedy.
    if(is_numeric($search))
      {
        $method="year_search";
        $col = "authority_year";
        $loose = true; # Always true because of the way data is stored
        $params[$col] = $search;
        $r = $db->doQuery($params,"*",$boolean_type,$loose,true);
        #######TODO HANDLE ERROR
        while($row = mysqli_fetch_assoc($r))
          {
            $result_vector[] = $row;
          }
      }
    else if (strpos(" ",$search) === false)
      {
        $method="spaceless_search";
        # No space in search
        if($boolean_type !== false)
          {
            # Handle the complicated statement. It'll need to be
            # escaped from normal handling.
            $result_vector = handleParamSearch();
          }
        else
          {
            $boolean_type = "OR";
            $params["common_name"] = $search;
            $params["genus"] = $search;
            $params["species"] = $search;
            $params["major_common_type"] = $search;
            $params["major_subtype"] = $search;
            $params["deprecated_scientific"] = $search;
            if(!$flag_fuzzy)
              {
                $r = $db->doQuery($params,"*",$boolean_type,$loose,true);
                #######TODO HANDLE ERROR
                while($row = mysqli_fetch_assoc($r))
                  {
                    $result_vector[] = $row;
                  }
              }
            else
              {
                foreach($params as $search_column=>$search_criteria)
                  {
                    $r = $db->doSoundex(array($search_column=>$search_criteria),"*",true);
                    ############ TODO HANDLE ERRORS
                    while($row = mysqli_fetch_assoc($r))
                      {
                        $result_vector[] = $row;
                      }
                  }
              }
          }
      }
    else
      {
        # Spaces in search
        if($boolean_type !== false)
          {
            # Handle the complicated statement. It'll need to be
            # escaped from normal handling.
            $result_vector = handleParamSearch();
          }
        else
          {
            $exp = explode(" ",$search);
            $fallback = true;
            if(sizeof($exp) == 2 || sizeof($exp) == 3)
              {
                $boolean_type = "and";
                $params["genus"] = $exp[0];
                $params["species"] = $exp[1];
                if(sizeof($exp) == 3) $params["subspecies"] = $exp[2];
                $r = $db->doQuery($params,"*",$boolean_type,$loose,true);
                #######TODO HANDLE ERROR
                if(mysqli_num_rows($r) > 0)
                  {
                    while($row = mysqli_fetch_assoc($r))
                      {
                        $result_vector[] = $row;
                      }
                    $method = "scientific";
                    $fallback = false;
                  }
                else
                  {
                    # Always has to be a loose query
                    $r = $db->doQuery(array("deprecated_scientific"=>$search),"*",$boolean_type,true,true);
                    ###### TODO HANDLE ERRORS
                    while($row = mysqli_fetch_assoc($r))
                      {
                        $result_vector[] = $row;
                      }
                    $method = "deprecated_scientific";
                    $fallback = false;
                  }
              }
            if($fallback)
              {
                $method = "space_fallback";
                $params["common_name"] = $search;
                $r = $db->doQuery($params,"*",$boolean_type,$loose,true);
                while($row = mysqli_fetch_assoc($r))
                  {
                    $result_vector[] = $row;
                  }
              }
          }
      }
  }
else
  {
    $result_vector = handleParamSearch();
  }

returnAjax(array("status"=>true,"result"=>$result_vector,"count"=>sizeof($result_vector),"method"=>$method));


?>