// Generated by CoffeeScript 1.7.1
(function() {
  var animateLoad, byteCount, checkMatchPassword, checkPasswordLive, delay, doEmailCheck, doTOTPRemove, doTOTPSubmit, evalRequirements, giveAltVerificationOptions, isBlank, isBool, isEmpty, isJson, isNull, isNumber, makeTOTP, mapNewWindows, noSubmit, popupSecret, root, roundNumber, saveTOTP, showInstructions, stopLoad, stopLoadError, toFloat, toInt, toggleNewUserSubmit, url, verifyPhone, _base, _base1,
    __slice = [].slice;

  root = typeof exports !== "undefined" && exports !== null ? exports : this;

  isBool = function(str) {
    return str === true || str === false;
  };

  isEmpty = function(str) {
    return !str || str.length === 0;
  };

  isBlank = function(str) {
    return !str || /^\s*$/.test(str);
  };

  isNull = function(str) {
    try {
      if (isEmpty(str) || isBlank(str) || (str == null)) {
        if (!(str === false || str === 0)) {
          return true;
        }
      }
    } catch (_error) {

    }
    return false;
  };

  isJson = function(str) {
    if (typeof str === 'object') {
      return true;
    }
    try {
      JSON.parse(str);
      return true;
    } catch (_error) {

    }
    return false;
  };

  isNumber = function(n) {
    return !isNaN(parseFloat(n)) && isFinite(n);
  };

  toFloat = function(str) {
    if (!isNumber(str) || isNull(str)) {
      return 0;
    }
    return parseFloat(str);
  };

  toInt = function(str) {
    if (!isNumber(str) || isNull(str)) {
      return 0;
    }
    return parseInt(str);
  };

  function toObject(arr) {
    var rv = {};
    for (var i = 0; i < arr.length; ++i)
        if (arr[i] !== undefined) rv[i] = arr[i];
    return rv;
};

  String.prototype.toBool = function() {
    return this.toString() === 'true';
  };

  Boolean.prototype.toBool = function() {
    return this.toString() === 'true';
  };

  Object.size = function(obj) {
    var key, size;
    size = 0;
    for (key in obj) {
      if (obj.hasOwnProperty(key)) {
        size++;
      }
    }
    return size;
  };

  delay = function(ms, f) {
    return setTimeout(f, ms);
  };

  roundNumber = function(number, digits) {
    var multiple;
    if (digits == null) {
      digits = 0;
    }
    multiple = Math.pow(10, digits);
    return Math.round(number * multiple) / multiple;
  };

  jQuery.fn.exists = function() {
    return jQuery(this).length > 0;
  };

  jQuery.fn.isVisible = function() {
    return jQuery(this).css("display") !== "none";
  };

  jQuery.fn.hasChildren = function() {
    return Object.size(jQuery(this).children()) > 3;
  };

  byteCount = (function(_this) {
    return function(s) {
      return encodeURI(s).split(/%..|./).length - 1;
    };
  })(this);

  function shuffle(o) { //v1.0
    for (var j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);
    return o;
};

  window.debounce_timer = null;

  ({
    debounce: function(func, threshold, execAsap) {
      if (threshold == null) {
        threshold = 300;
      }
      if (execAsap == null) {
        execAsap = false;
      }
      return function() {
        var args, delayed, obj;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        obj = this;
        delayed = function() {
          if (!execAsap) {
            return func.apply(obj, args);
          }
        };
        if (window.debounce_timer != null) {
          clearTimeout(window.debounce_timer);
        } else if (execAsap) {
          func.apply(obj, args);
        }
        return window.debounce_timer = setTimeout(delayed, threshold);
      };
    }
  });

  Function.prototype.debounce = function() {
    var args, delayed, e, execAsap, func, threshold, timeout;
    threshold = arguments[0], execAsap = arguments[1], timeout = arguments[2], args = 4 <= arguments.length ? __slice.call(arguments, 3) : [];
    if (threshold == null) {
      threshold = 300;
    }
    if (execAsap == null) {
      execAsap = false;
    }
    if (timeout == null) {
      timeout = window.debounce_timer;
    }
    func = this;
    delayed = function() {
      if (!execAsap) {
        func.apply(func, args);
      }
      return console.log("Debounce applied");
    };
    if (timeout != null) {
      try {
        clearTimeout(timeout);
      } catch (_error) {
        e = _error;
      }
    } else if (execAsap) {
      func.apply(obj, args);
      console.log("Executed immediately");
    }
    return window.debounce_timer = setTimeout(delayed, threshold);
  };

  mapNewWindows = function() {
    return $(".newwindow").each(function() {
      var curHref, openInNewWindow;
      curHref = $(this).attr("href");
      openInNewWindow = function(url) {
        if (url == null) {
          return false;
        }
        window.open(url);
        return false;
      };
      $(this).click(function() {
        return openInNewWindow(curHref);
      });
      return $(this).keypress(function() {
        return openInNewWindow(curHref);
      });
    });
  };

  animateLoad = function(d, elId) {
    var big, e, offset, offset2, sm_d, small;
    if (d == null) {
      d = 50;
    }
    if (elId == null) {
      elId = "#status-container";
    }
    try {
      if ($(elId).exists()) {
        sm_d = roundNumber(d * .5);
        big = $(elId).find('.ball');
        small = $(elId).find('.ball1');
        big.removeClass('stop hide');
        big.css({
          width: "" + d + "px",
          height: "" + d + "px"
        });
        offset = roundNumber(d / 2 + sm_d / 2 + 9);
        offset2 = roundNumber((d + 10) / 2 - (sm_d + 6) / 2);
        small.removeClass('stop hide');
        small.css({
          width: "" + sm_d + "px",
          height: "" + sm_d + "px",
          top: "-" + offset + "px",
          'margin-left': "" + offset2 + "px"
        });
        return true;
      }
      return false;
    } catch (_error) {
      e = _error;
      return console.log('Could not animate loader', e.message);
    }
  };

  stopLoad = function(elId) {
    var big, e, small;
    if (elId == null) {
      elId = "#status-container";
    }
    try {
      if ($(elId).exists()) {
        big = $(elId).find('.ball');
        small = $(elId).find('.ball1');
        big.addClass('bballgood ballgood');
        small.addClass('bballgood ball1good');
        return delay(250, function() {
          big.addClass('stop hide');
          big.removeClass('bballgood ballgood');
          small.addClass('stop hide');
          return small.removeClass('bballgood ballgood');
        });
      }
    } catch (_error) {
      e = _error;
      return console.log('Could not stop load animation', e.message);
    }
  };

  stopLoadError = function(elId) {
    var big, e, small;
    if (elId == null) {
      elId = "#status-container";
    }
    try {
      if ($(elId).exists()) {
        big = $(elId).find('.ball');
        small = $(elId).find('.ball1');
        big.addClass('bballerror ballerror');
        small.addClass('bballerror ball1error');
        return delay(1500, function() {
          big.addClass('stop hide');
          big.removeClass('bballerror ballerror');
          small.addClass('stop hide');
          return small.removeClass('bballerror ballerror');
        });
      }
    } catch (_error) {
      e = _error;
      return console.log('Could not stop load error animation', e.message);
    }
  };

  $(function() {
    var e;
    try {
      window.picturefill();
    } catch (_error) {
      e = _error;
      console.log("Could not execute picturefill.");
    }
    return mapNewWindows();
  });

  if (typeof window.passwords !== 'object') {
    window.passwords = new Object();
  }

  window.passwords.goodbg = "#cae682";

  window.passwords.badbg = "#e5786d";

  if ((_base = window.passwords).minLength == null) {
    _base.minLength = 8;
  }

  if ((_base1 = window.passwords).overrideLength == null) {
    _base1.overrideLength = 21;
  }

  if (typeof window.totpParams !== 'object') {
    window.totpParams = new Object();
  }

  window.totpParams.mainStylesheetPath = "css/otp_styles.css";

  window.totpParams.popStylesheetPath = "css/otp_panels.css";

  window.totpParams.popClass = "pop-panel";

  if (window.totpParams.home == null) {
    url = $.url();
    window.totpParams.home = url.attr('protocol') + '://' + url.attr('host') + '/';
  }

  checkPasswordLive = function() {
    var pass;
    pass = $("#password").val();
    if (pass.length > window.passwords.overrideLength || pass.match(/^(?:(?=^.{8,}$)((?=.*\d)|(?=.*\W+))(?![.\n])(?=.*[A-Z])(?=.*[a-z]).*$)$/)) {
      $("#password").css("background", window.passwords.goodbg);
      window.passwords.basepwgood = true;
    } else {
      $("#password").css("background", window.passwords.badbg);
      window.passwords.basepwgood = false;
    }
    evalRequirements();
    if (!isNull($("#password2").val())) {
      checkMatchPassword();
      toggleNewUserSubmit();
    }
    return false;
  };

  checkMatchPassword = function() {
    if ($("#password").val() === $("#password2").val()) {
      $('#password2').css('background', window.passwords.goodbg);
      window.passwords.passmatch = true;
    } else {
      $('#password2').css('background', window.passwords.badbg);
      window.passwords.passmatch = false;
    }
    toggleNewUserSubmit();
    return false;
  };

  toggleNewUserSubmit = function() {
    var dbool, e;
    try {
      dbool = !(window.passwords.passmatch && window.passwords.basepwgood);
      return $("#createUser_submit").attr("disabled", dbool);
    } catch (_error) {
      e = _error;
      window.passwords.passmatch = false;
      return window.passwords.basepwgood = false;
    }
  };

  evalRequirements = function() {
    var html, pass, pstrength;
    if (!$("#strength-meter").exists()) {
      html = "<div id='strength-meter'><div id='strength-requirements'><div id='strength-alpha'><p class='label'>a</p><div class='strength-eval'></div></div><div id='strength-alphacap'><p class='label'>A</p><div class='strength-eval'></div></div><div id='strength-numspecial'><p class='label'>1/!</p><div class='strength-eval'></div></div></div><div id='strength-bar'><label for='password-strength'>Strength: </label><progress id='password-strength' max='5'></progress></div></div>";
      $("#login .right").prepend(html);
    }
    pass = $("#password").val();
    pstrength = zxcvbn(pass);
    $(".strength-eval").css("background", window.passwords.badbg);
    if (pass.length > 20) {
      $(".strength-eval").css("background", window.passwords.goodbg);
    } else {
      if (pass.match(/^(?:((?=.*\d)|(?=.*\W+)).*$)$/)) {
        $("#strength-numspecial .strength-eval").css("background", window.passwords.goodbg);
      }
      if (pass.match(/^(?=.*[a-z]).*$/)) {
        $("#strength-alpha .strength-eval").css("background", window.passwords.goodbg);
      }
      if (pass.match(/^(?=.*[A-Z]).*$/)) {
        $("#strength-alphacap .strength-eval").css("background", window.passwords.goodbg);
      }
    }
    return $("#password-strength").attr("value", pstrength.score + 1);
  };

  doEmailCheck = function() {};

  doTOTPSubmit = function(home) {
    var ajaxLanding, args, code, ip, pass, totp, urlString, user;
    if (home == null) {
      home = window.totpParams.home;
    }
    noSubmit();
    animateLoad();
    code = $("#totp_code").val();
    user = $("#username").val();
    pass = $("#password").val();
    ip = $("#remote").val();
    url = $.url();
    ajaxLanding = "async_login_handler.php";
    urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../" + ajaxLanding;
    args = "action=verifytotp&code=" + code + "&user=" + user + "&password=" + pass + "&remote=" + ip;
    totp = $.post(urlString, args, 'json');
    totp.done(function(result) {
      var e, i;
      if (result.status === true) {
        try {
          $("#totp_message").text("Correct!").removeClass("error").addClass("good");
          i = 0;
          return $.each(result["cookies"].raw_cookie, function(key, val) {
            var e;
            try {
              $.cookie(key, val, result["cookies"].expires);
            } catch (_error) {
              e = _error;
              console.error("Couldn't set cookies", result["cookies"].raw_cookie);
            }
            i++;
            if (i === Object.size(result["cookies"].raw_cookie)) {
              if (home == null) {
                home = url.attr('protocol') + '://' + url.attr('host') + '/';
              }
              stopLoad();
              return delay(500, function() {
                return window.location.href = home;
              });
            }
          });
        } catch (_error) {
          e = _error;
          return console.error("Unexpected error while validating", e.message);
        }
      } else {
        $("#totp_message").text(result.human_error);
        $("#totp_code").val("");
        $("#totp_code").focus();
        stopLoadError();
        return console.error("Invalid code error", result.error, result);
      }
    });
    return totp.fail(function(result, status) {
      $("#totp_message").text("Failed to contact server. Please try again.");
      console.error("AJAX failure", urlString + "?" + args, result, status);
      return stopLoadError();
    });
  };

  doTOTPRemove = function() {
    return noSubmit();
  };

  makeTOTP = function() {
    var ajaxLanding, args, hash, key, password, totp, urlString, user;
    noSubmit();
    animateLoad();
    user = $("#username").val();
    password = $("#password").val();
    hash = $("#hash").val();
    key = $("#secret").val();
    url = $.url();
    ajaxLanding = "async_login_handler.php";
    urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../" + ajaxLanding;
    args = "action=maketotp&password=" + password + "&user=" + user;
    totp = $.post(urlString, args, 'json');
    totp.done(function(result) {
      var barcodeDiv, html, raw, show_alt, show_secret_id, svg;
      if (result.status === true) {
        svg = result.svg;
        raw = result.raw;
        show_secret_id = "show_secret";
        show_alt = "showAltBarcode";
        barcodeDiv = "secretBarcode";
        html = "<form id='totp_verify'> <p>To continue, scan this barcode with your smartphone application.</p> <p style='font-weight:bold'>If you're unable to do so, <a href='#' id='" + show_secret_id + "'>click here to manually input your key.</a></p> <div id='" + barcodeDiv + "'> " + result.svg + " <p>Don't see the barcode? <a href='#' id='" + show_alt + "'>Click here</a></p> </div> <p>Once you've done so, enter your code below to verify your setup.</p> <fieldset> <legend>Confirmation</legend> <input type='number' size='6' maxlength='6' id='code' name='code' placeholder='Code'/> <input type='hidden' id='username' name='username' value='" + user + "'/> <button id='verify_totp_button' class='totpbutton'>Verify</button> </fieldset> </form>";
        $("#totp_add").html(html);
        $("#" + show_secret_id).click(function() {
          return popupSecret(result.human_secret);
        });
        $("#" + show_alt).click(function() {
          var altImg;
          altImg = "<img src='" + result.raw + "' alt='TOTP barcode'/>";
          return $("" + barcode_div).html(altImg);
        });
        $("#verify_totp_button").click(function() {
          noSubmit();
          return saveTOTP(key, hash);
        });
        $("#totp_verify").submit(function() {
          noSubmit();
          return saveTOTP(key, hash);
        });
        return stopLoad();
      } else {
        console.error("Couldn't generate TOTP code", urlString + "?" + args);
        $("#totp_message").text("There was an error generating your code. Please try again.");
        return stopLoadError();
      }
    });
    totp.fail(function(result, status) {
      $("#totp_message").text("Failed to contact server. Please try again.");
      console.error("AJAX failure", urlString + "?" + args, result, status);
      return stopLoadError();
    });
    return false;
  };

  saveTOTP = function(key, hash) {
    var ajaxLanding, args, code, totp, urlString, user;
    noSubmit();
    code = $("#code").val();
    user = $("#username").val();
    url = $.url();
    ajaxLanding = "async_login_handler.php";
    urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../" + ajaxLanding;
    args = "action=savetotp&secret=" + key + "&user=" + user + "&hash=" + hash + "&code=" + code;
    totp = $.post(urlString, args, 'json');
    totp.done(function(result) {
      var html;
      if (result.status === true) {
        html = "<h1>Done!</h1><h2>Write down and save this backup code. Without it, you cannot disable two-factor authentication if you lose your device.</h2><pre id='backup_code'>" + result.backup + "</pre><br/><button id='to_home'>Home &#187;</a>";
        $("#totp_add").html(html);
        $("#to_home").click(function() {
          return window.location.href = window.totpParams.home;
        });
        return stopLoad();
      } else {
        html = "<p class='error' id='temp_error'>" + result.human_error + "</p>";
        if (!$("#temp_error").exists()) {
          $("#verify_totp_button").after(html);
        } else {
          $("#temp_error").html(html);
        }
        console.error(result.error);
        return stopLoadError();
      }
    });
    return totp.fail(function(result, status) {
      $("#totp_message").text("Failed to contact server. Please try again.");
      console.error("AJAX failure", result, status);
      return stopLoadError();
    });
  };

  popupSecret = function(secret) {
    var html;
    $("<link/>", {
      rel: "stylesheet",
      type: "text/css",
      media: "screen",
      href: window.totpParams.popStylesheetPath
    }).appendTo("head");
    html = "<div id='cover_wrapper'><div id='secret_id_panel' class='" + window.totpParams.popClass + " cover_content'><p class='close-popup'>X</p><h2>" + secret + "</h2></div></div>";
    $("article").after(html);
    $("article").addClass("blur");
    return $(".close-popup").click(function() {
      $("#cover_wrapper").remove();
      return $("article").removeClass("blur");
    });
  };

  giveAltVerificationOptions = function() {
    var ajaxLanding, args, messages, pane_id, pane_messages, remove_id, sms, sms_id, urlString, user;
    url = $.url();
    ajaxLanding = "async_login_handler.php";
    urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../" + ajaxLanding;
    user = $("#username").val();
    args = "action=cansms&user=" + user;
    remove_id = "remove_totp_link";
    sms_id = "send_totp_sms";
    pane_id = "alt_auth_pane";
    pane_messages = "alt_auth_messages";
    messages = new Object();
    messages.remove = "<a href='#' id='" + remove_id + "'>Remove two-factor authentication</a>";
    sms = $.get(urlString, args, 'json');
    sms.done(function(result) {
      var html, pop_content;
      if (result[0] === true) {
        messages.sms = "<a href='#' id='" + sms_id + "'>Send SMS</a>";
      } else {
        console.warn("Couldn't get a valid result", result, urlString + "?" + args);
      }
      pop_content = "";
      $.each(messages, function(k, v) {
        return pop_content += v;
      });
      html = "<div id='" + pane_id + "'><p>" + pop_content + "</p><p id='" + pane_messages + "'></p></div>";
      $("#totp_submit").after(html);
      return $("#" + sms_id).click(function() {
        var sms_totp;
        args = "action=sendtotptext&user=" + user;
        sms_totp = $.get(urlString, args, 'json');
        console.log("Sending message ...", urlString + "?" + args);
        sms_totp.done(function(result) {
          if (result.status === true) {
            $("#" + pane_id).remove();
            return $("#totp_message").text(result.message);
          } else {
            $("#" + pane_messages).addClass("error").text(result.human_error);
            return console.error(result.error);
          }
        });
        return sms_totp.fail(function(result, status) {
          console.error("AJAX failure trying to send TOTP text", urlString + "?" + args);
          return console.error("Returns:", result, status);
        });
      });
    });
    sms.fail(function(result, status) {
      return console.error("Could not check SMS-ability", result, status);
    });
    return sms.always(function() {
      return $("#" + remove_id).click(function() {
        var _base2;
        if ((_base2 = window.totpParams).home == null) {
          _base2.home = url.attr('protocol') + '://' + url.attr('host') + '/login.php';
        }
        return window.location.href = window.totpParams.home + "?2fa=t";
      });
    });
  };

  verifyPhone = function() {
    var ajaxLanding, args, auth, urlString, user, verifyPhoneAjax;
    noSubmit();
    url = $.url();
    ajaxLanding = "async_login_handler.php";
    urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../" + ajaxLanding;
    auth = $("#phone_auth").val() != null ? $("#phone_auth").val() : null;
    user = $("#username").val();
    args = "action=verifyphone&username=" + user + "&auth=" + auth;
    verifyPhoneAjax = $.get(urlString, args, 'json');
    verifyPhoneAjax.done(function(result) {
      var message, setClass;
      if (result.status === false) {
        if (!$("#phone_verify_message").exists()) {
          $("#phone").before("<p id='phone_verify_message'></p>");
        }
        if (result.is_good === true) {
          $("#verify_phone_button").remove();
          message = "<p>You've already verified your phone number, thanks!</p>";
          setClass = "good";
        } else {
          message = result.human_error;
          setClass = "error";
        }
        $("#phone_verify_message").text(message).addClass(setClass);
        if (result.fatal === true) {
          $("#verify_phone_button").attr("disabled", true);
          $("#verify_phone").unbind('submit').attr("onsubmit", "");
        }
        return false;
      }
      if (result.status === true) {
        if (!$("#phone_auth").exists()) {
          $("#username").after("<br/><input type='text' length='8' name='phone_auth' id='phone_auth' placeholder='Authorization Code'/>");
        }
        if (!$("#phone_verify_message").exists()) {
          $("#phone").before("<p id='phone_verify_message'></p>");
        }
        $("#phone_verify_message").text(result.message);
        if (result.is_good !== true) {
          return $("#verify_phone_button").text("Confirm");
        } else {
          $("#phone_auth").remove();
          $("#verify_later").remove();
          return $("#verify_phone_button").html("Continue &#187; ").unbind('click').click(function() {
            return window.location.href = window.totpParams.home;
          });
        }
      } else {
        console.warn("Unexpected condition encountered verifying the phone number", urlString);
        console.log(result);
        return false;
      }
    });
    return verifyPhoneAjax.fail(function(result, status) {
      console.error("AJAX failure trying to send phone verification text", urlString + "?" + args);
      return console.error("Returns:", result, status);
    });
  };

  showInstructions = function(path) {
    if (path == null) {
      path = "help/instructions_pop.html";
    }
    $("<link/>", {
      rel: "stylesheet",
      type: "text/css",
      media: "screen",
      href: window.totpParams.popStylesheetPath
    }).appendTo("head");
    return $.get(path).done(function(html) {
      var assetPath, urlString;
      $("article").after(html);
      $("article").addClass("blur");
      url = $.url();
      urlString = url.attr('protocol') + '://' + url.attr('host') + '/' + url.attr('directory') + "/../";
      assetPath = "" + urlString + "assets/";
      $(".android").html("<img src='" + assetPath + "playstore.png' alt='Google Play Store'/>");
      $(".ios").html("<img src='" + assetPath + "appstore.png' alt='iOS App Store'/>");
      $(".wp8").html("<img src='" + assetPath + "wpstore.png' alt='Windows Phone Store'/>");
      $(".app_link_container a").addClass("newwindow");
      mapNewWindows();
      return $(".close-popup").click(function() {
        $("article").removeClass("blur");
        return $("#cover_wrapper").remove();
      });
    }).fail(function(result, status) {
      return console.error("Failed to load instructions @ " + path, result, status);
    });
  };

  noSubmit = function() {
    event.preventDefault();
    return event.returnValue = false;
  };

  $(function() {
    $("#password.create").keyup(function() {
      return checkPasswordLive();
    }).change(function() {
      return checkPasswordLive();
    });
    $("#password2").change(function() {
      return checkMatchPassword();
    }).keyup(function() {
      return checkMatchPassword();
    });
    $("#totp_submit").submit(function() {
      return doTOTPSubmit();
    });
    $("#verify_totp_button").click(function() {
      return doTOTPSubmit();
    });
    $("#totp_start").submit(function() {
      return makeTOTP();
    });
    $("#add_totp_button").click(function() {
      return makeTOTP();
    });
    $("#totp_remove").submit(function() {
      return doTOTPRemove();
    });
    $("#remove_totp_button").click(function() {
      return doTOTPRemove();
    });
    $("#alternate_verification_prompt").click(function() {
      return giveAltVerificationOptions();
    });
    $("#verify_phone").submit(function() {
      return verifyPhone();
    });
    $("#verify_phone_button").click(function() {
      return verifyPhone();
    });
    $("#verify_later").click(function() {
      return window.location.href = window.totpParams.home;
    });
    $("#totp_help").click(function() {
      return showInstructions();
    });
    if ($.url().param("showhelp") != null) {
      showInstructions();
    }
    return $("<link/>", {
      rel: "stylesheet",
      type: "text/css",
      media: "screen",
      href: window.totpParams.mainStylesheetPath
    }).appendTo("head");
  });

}).call(this);
