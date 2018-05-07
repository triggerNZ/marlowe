{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

module Fay.Runtime where

import Text.Shakespeare.Text
import Data.Text.Lazy as T
import Fay.Config

-- | Get the default runtime source.
getRuntimeSource :: Config -> String
getRuntimeSource cfg = "\n/*******************************************************************************\n * Misc.\n */\n\n\n// Workaround for missing functionality in IE 8 and earlier.\nif( Object.create === undefined ) {\n  Object.create = function( o ) {\n    function F(){}\n    F.prototype = o;\n    return new F();\n  };\n}\n\n// Insert properties of b in place into a.\nfunction Fay$$objConcat(a,b){\n  for (var p in b) if (b.hasOwnProperty(p)){\n    a[p] = b[p];\n  }\n  return a;\n}\n\n/*******************************************************************************\n * Thunks.\n */\n\n// Force a thunk (if it is a thunk) until WHNF.\nfunction Fay$$_(thunkish,nocache){\n  while (thunkish instanceof Fay$$$) {\n    thunkish = thunkish.force(nocache);\n  }\n  return thunkish;\n}\n\n// Apply a function to arguments (see method2 in Fay.hs).\nfunction Fay$$__(){\n  var f = arguments[0];\n  for (var i = 1, len = arguments.length; i < len; i++) {\n    f = (f instanceof Fay$$$? Fay$$_(f) : f)(arguments[i]);\n  }\n  return f;\n}\n\n// Thunk object.\nfunction Fay$$$(value){\n  this.forced = false;\n  this.value = value;\n}\n\n// Force the thunk.\nFay$$$.prototype.force = function(nocache) {\n  return nocache ?\n    this.value() :\n    (this.forced ?\n     this.value :\n     (this.value = this.value(), this.forced = true, this.value));\n};\n\n\nfunction Fay$$seq(x) {\n  return function(y) {\n    Fay$$_(x,false);\n    return y;\n  }\n}\n\nfunction Fay$$seq$36$uncurried(x,y) {\n  Fay$$_(x,false);\n  return y;\n}\n\n/*******************************************************************************\n * Monad.\n */\n\nfunction Fay$$Monad(value){\n  this.value = value;\n}\n\n// This is used directly from Fay, but can be rebound or shadowed. See primOps in Types.hs.\n// >>\nfunction Fay$$then(a){\n  return function(b){\n    return Fay$$bind(a)(function(_){\n      return b;\n    });\n  };\n}\n\n// This is used directly from Fay, but can be rebound or shadowed. See primOps in Types.hs.\n// >>\nfunction Fay$$then$36$uncurried(a,b){\n  return Fay$$bind$36$uncurried(a,function(_){ return b; });\n}\n\n// >>=\n// This is used directly from Fay, but can be rebound or shadowed. See primOps in Types.hs.\nfunction Fay$$bind(m){\n  return function(f){\n    return new Fay$$$(function(){\n      var monad = Fay$$_(m,true);\n      return Fay$$_(f)(monad.value);\n    });\n  };\n}\n\n// >>=\n// This is used directly from Fay, but can be rebound or shadowed. See primOps in Types.hs.\nfunction Fay$$bind$36$uncurried(m,f){\n  return new Fay$$$(function(){\n    var monad = Fay$$_(m,true);\n    return Fay$$_(f)(monad.value);\n  });\n}\n\n// This is used directly from Fay, but can be rebound or shadowed.\nfunction Fay$$$_return(a){\n  return new Fay$$Monad(a);\n}\n\n// Allow the programmer to access thunk forcing directly.\nfunction Fay$$force(thunk){\n  return function(type){\n    return new Fay$$$(function(){\n      Fay$$_(thunk,type);\n      return new Fay$$Monad(Fay$$unit);\n    })\n  }\n}\n\n// This is used directly from Fay, but can be rebound or shadowed.\nfunction Fay$$return$36$uncurried(a){\n  return new Fay$$Monad(a);\n}\n\n// Unit: ().\nvar Fay$$unit = null;\n\n/*******************************************************************************\n * Serialization.\n * Fay <-> JS. Should be bijective.\n */\n\n// Serialize a Fay object to JS.\nfunction Fay$$fayToJs(type,fayObj){\n  var base = type[0];\n  var args = type[1];\n  var jsObj;\n  if(base == \"action\") {\n    // A nullary monadic action. Should become a nullary JS function.\n    // Fay () -> function(){ return ... }\n    return function(){\n      return Fay$$fayToJs(args[0],Fay$$_(fayObj,true).value);\n    };\n\n  }\n  else if(base == \"function\") {\n    // A proper function.\n    return function(){\n      var fayFunc = fayObj;\n      var return_type = args[args.length-1];\n      var len = args.length;\n      // If some arguments.\n      if (len > 1) {\n        // Apply to all the arguments.\n        fayFunc = Fay$$_(fayFunc,true);\n        // TODO: Perhaps we should throw an error when JS\n        // passes more arguments than Haskell accepts.\n\n        // Unserialize the JS values to Fay for the Fay callback.\n        if (args == \"automatic_function\")\n        {\n          for (var i = 0; i < arguments.length; i++) {\n            fayFunc = Fay$$_(fayFunc(Fay$$jsToFay([\"automatic\"],arguments[i])),true);\n          }\n          return Fay$$fayToJs([\"automatic\"], fayFunc);\n        }\n\n        for (var i = 0, len = len; i < len - 1 && fayFunc instanceof Function; i++) {\n          fayFunc = Fay$$_(fayFunc(Fay$$jsToFay(args[i],arguments[i])),true);\n        }\n        // Finally, serialize the Fay return value back to JS.\n        var return_base = return_type[0];\n        var return_args = return_type[1];\n        // If it's a monadic return value, get the value instead.\n        if(return_base == \"action\") {\n          return Fay$$fayToJs(return_args[0],fayFunc.value);\n        }\n        // Otherwise just serialize the value direct.\n        else {\n          return Fay$$fayToJs(return_type,fayFunc);\n        }\n      } else {\n        throw new Error(\"Nullary function?\");\n      }\n    };\n\n  }\n  else if(base == \"string\") {\n    return Fay$$fayToJs_string(fayObj);\n  }\n  else if(base == \"list\") {\n    // Serialize Fay list to JavaScript array.\n    var arr = [];\n    fayObj = Fay$$_(fayObj);\n    while(fayObj instanceof Fay$$Cons) {\n      arr.push(Fay$$fayToJs(args[0],fayObj.car));\n      fayObj = Fay$$_(fayObj.cdr);\n    }\n    return arr;\n  }\n  else if(base == \"tuple\") {\n    // Serialize Fay tuple to JavaScript array.\n    var arr = [];\n    fayObj = Fay$$_(fayObj);\n    var i = 0;\n    while(fayObj instanceof Fay$$Cons) {\n      arr.push(Fay$$fayToJs(args[i++],fayObj.car));\n      fayObj = Fay$$_(fayObj.cdr);\n    }\n    return arr;\n  }\n  else if(base == \"defined\") {\n    fayObj = Fay$$_(fayObj);\n    return fayObj instanceof Fay.FFI._Undefined\n      ? undefined\n      : Fay$$fayToJs(args[0],fayObj.slot1);\n  }\n  else if(base == \"nullable\") {\n    fayObj = Fay$$_(fayObj);\n    return fayObj instanceof Fay.FFI._Null\n      ? null\n      : Fay$$fayToJs(args[0],fayObj.slot1);\n  }\n  else if(base == \"double\" || base == \"int\" || base == \"bool\") {\n    // Bools are unboxed.\n    return Fay$$_(fayObj);\n  }\n  else if(base == \"ptr\")\n    return fayObj;\n  else if(base == \"unknown\")\n    return Fay$$fayToJs([\"automatic\"], fayObj);\n  else if(base == \"automatic\" && fayObj instanceof Function) {\n    return Fay$$fayToJs([\"function\", \"automatic_function\"], fayObj);\n  }\n  else if(base == \"automatic\" || base == \"user\") {\n    fayObj = Fay$$_(fayObj);\n\n    if(fayObj instanceof Fay$$Cons || fayObj === null){\n      // Serialize Fay list to JavaScript array.\n      var arr = [];\n      while(fayObj instanceof Fay$$Cons) {\n        arr.push(Fay$$fayToJs([\"automatic\"],fayObj.car));\n        fayObj = Fay$$_(fayObj.cdr);\n      }\n      return arr;\n    } else {\n      var fayToJsFun = fayObj && fayObj.instance && Fay$$fayToJsHash[fayObj.instance];\n      return fayToJsFun ? fayToJsFun(type,type[2],fayObj) : fayObj;\n    }\n  }\n\n  throw new Error(\"Unhandled Fay->JS translation type: \" + base);\n}\n\n// Stores the mappings from fay types to js objects.\n// This will be populated by compiled modules.\nvar Fay$$fayToJsHash = {};\n\n// Specialized serializer for string.\nfunction Fay$$fayToJs_string(fayObj){\n  // Serialize Fay string to JavaScript string.\n  var str = \"\";\n  fayObj = Fay$$_(fayObj);\n  while(fayObj instanceof Fay$$Cons) {\n    str += Fay$$_(fayObj.car);\n    fayObj = Fay$$_(fayObj.cdr);\n  }\n  return str;\n};\nfunction Fay$$jsToFay_string(x){\n  return Fay$$list(x)\n};\n\n// Special num/bool serializers.\nfunction Fay$$jsToFay_int(x){return x;}\nfunction Fay$$jsToFay_double(x){return x;}\nfunction Fay$$jsToFay_bool(x){return x;}\n\nfunction Fay$$fayToJs_int(x){return Fay$$_(x);}\nfunction Fay$$fayToJs_double(x){return Fay$$_(x);}\nfunction Fay$$fayToJs_bool(x){return Fay$$_(x);}\n\n// Unserialize an object from JS to Fay.\nfunction Fay$$jsToFay(type,jsObj){\n  var base = type[0];\n  var args = type[1];\n  var fayObj;\n  if(base == \"action\") {\n    // Unserialize a \"monadic\" JavaScript return value into a monadic value.\n    return new Fay$$Monad(Fay$$jsToFay(args[0],jsObj));\n  }\n  else if(base == \"function\") {\n    // Unserialize a function from JavaScript to a function that Fay can call.\n    // So\n    //\n    //    var f = function(x,y,z){ \8230 }\n    //\n    // becomes something like:\n    //\n    //    function(x){\n    //      return function(y){\n    //        return function(z){\n    //          return new Fay$$$(function(){\n    //            return Fay$$jsToFay(f(Fay$$fayTojs(x),\n    //                                  Fay$$fayTojs(y),\n    //                                  Fay$$fayTojs(z))\n    //    }}}}};\n    var returnType = args[args.length-1];\n    var funArgs = args.slice(0,-1);\n\n    if (jsObj.length > 0) {\n      var makePartial = function(args){\n        return function(arg){\n          var i = args.length;\n          var fayArg = Fay$$fayToJs(funArgs[i],arg);\n          var newArgs = args.concat([fayArg]);\n          if(newArgs.length == funArgs.length) {\n            return new Fay$$$(function(){\n              return Fay$$jsToFay(returnType,jsObj.apply(this,newArgs));\n            });\n          } else {\n            return makePartial(newArgs);\n          }\n        };\n      };\n      return makePartial([]);\n    }\n    else\n      return function (arg) {\n        return Fay$$jsToFay([\"automatic\"], jsObj(Fay$$fayToJs([\"automatic\"], arg)));\n      };\n  }\n  else if(base == \"string\") {\n    // Unserialize a JS string into Fay list (String).\n    // This is a special case, when String is explicit in the type signature,\n    // with `Automatic' a string would not be decoded.\n    return Fay$$list(jsObj);\n  }\n  else if(base == \"list\") {\n    // Unserialize a JS array into a Fay list ([a]).\n    var serializedList = [];\n    for (var i = 0, len = jsObj.length; i < len; i++) {\n      // Unserialize each JS value into a Fay value, too.\n      serializedList.push(Fay$$jsToFay(args[0],jsObj[i]));\n    }\n    // Pop it all in a Fay list.\n    return Fay$$list(serializedList);\n  }\n  else if(base == \"tuple\") {\n    // Unserialize a JS array into a Fay tuple ((a,b,c,...)).\n    var serializedTuple = [];\n    for (var i = 0, len = jsObj.length; i < len; i++) {\n      // Unserialize each JS value into a Fay value, too.\n      serializedTuple.push(Fay$$jsToFay(args[i],jsObj[i]));\n    }\n    // Pop it all in a Fay list.\n    return Fay$$list(serializedTuple);\n  }\n  else if(base == \"defined\") {\n    return jsObj === undefined\n      ? new Fay.FFI._Undefined()\n      : new Fay.FFI._Defined(Fay$$jsToFay(args[0],jsObj));\n  }\n  else if(base == \"nullable\") {\n    return jsObj === null\n      ? new Fay.FFI._Null()\n      : new Fay.FFI.Nullable(Fay$$jsToFay(args[0],jsObj));\n  }\n  else if(base == \"int\") {\n    // Int are unboxed, so there's no forcing to do.\n    // But we can do validation that the int has no decimal places.\n    // E.g. Math.round(x)!=x? throw \"NOT AN INTEGER, GET OUT!\"\n    fayObj = Math.round(jsObj);\n    if(fayObj!==jsObj) throw \"Argument \" + jsObj + \" is not an integer!\";\n    return fayObj;\n  }\n  else if (base == \"double\" ||\n           base == \"bool\" ||\n           base ==  \"ptr\") {\n    return jsObj;\n  }\n  else if(base == \"unknown\")\n    return Fay$$jsToFay([\"automatic\"], jsObj);\n  else if(base == \"automatic\" && jsObj instanceof Function) {\n    var type = [[\"automatic\"]];\n    for (var i = 0; i < jsObj.length; i++)\n      type.push([\"automatic\"]);\n    return Fay$$jsToFay([\"function\", type], jsObj);\n  }\n  else if(base == \"automatic\" && jsObj instanceof Array) {\n    var list = null;\n    for (var i = jsObj.length - 1; i >= 0; i--) {\n      list = new Fay$$Cons(Fay$$jsToFay([base], jsObj[i]), list);\n    }\n    return list;\n  }\n  else if(base == \"automatic\" || base == \"user\") {\n    if (jsObj && jsObj['instance']) {\n      var jsToFayFun = Fay$$jsToFayHash[jsObj[\"instance\"]];\n      return jsToFayFun ? jsToFayFun(type,type[2],jsObj) : jsObj;\n    }\n    else\n      return jsObj;\n  }\n\n  throw new Error(\"Unhandled JS->Fay translation type: \" + base);\n}\n\n// Stores the mappings from js objects to fay types.\n// This will be populated by compiled modules.\nvar Fay$$jsToFayHash = {};\n\n/*******************************************************************************\n * Lists.\n */\n\n// Cons object.\nfunction Fay$$Cons(car,cdr){\n  this.car = car;\n  this.cdr = cdr;\n}\n\n// Make a list.\nfunction Fay$$list(xs){\n  var out = null;\n  for(var i=xs.length-1; i>=0;i--)\n    out = new Fay$$Cons(xs[i],out);\n  return out;\n}\n\n// Built-in list cons.\nfunction Fay$$cons(x){\n  return function(y){\n    return new Fay$$Cons(x,y);\n  };\n}\n\n// List index.\n// `list' is already forced by the time it's passed to this function.\n// `list' cannot be null and `index' cannot be out of bounds.\nfunction Fay$$index(index,list){\n  for(var i = 0; i < index; i++) {\n    list = Fay$$_(list.cdr);\n  }\n  return list.car;\n}\n\n// List length.\n// `list' is already forced by the time it's passed to this function.\nfunction Fay$$listLen(list,max){\n  for(var i = 0; list !== null && i < max + 1; i++) {\n    list = Fay$$_(list.cdr);\n  }\n  return i == max;\n}\n\n/*******************************************************************************\n * Numbers.\n */\n\n// Built-in *.\nfunction Fay$$mult(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) * Fay$$_(y);\n    });\n  };\n}\n\nfunction Fay$$mult$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) * Fay$$_(y);\n  });\n\n}\n\n// Built-in +.\nfunction Fay$$add(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) + Fay$$_(y);\n    });\n  };\n}\n\n// Built-in +.\nfunction Fay$$add$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) + Fay$$_(y);\n  });\n\n}\n\n// Built-in -.\nfunction Fay$$sub(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) - Fay$$_(y);\n    });\n  };\n}\n// Built-in -.\nfunction Fay$$sub$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) - Fay$$_(y);\n  });\n\n}\n\n// Built-in /.\nfunction Fay$$divi(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) / Fay$$_(y);\n    });\n  };\n}\n\n// Built-in /.\nfunction Fay$$divi$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) / Fay$$_(y);\n  });\n\n}\n\n/*******************************************************************************\n * Booleans.\n */\n\n// Are two values equal?\nfunction Fay$$equal(lit1, lit2) {\n  // Simple case\n  lit1 = Fay$$_(lit1);\n  lit2 = Fay$$_(lit2);\n  if (lit1 === lit2) {\n    return true;\n  }\n  // General case\n  if (lit1 instanceof Array) {\n    if (lit1.length != lit2.length) return false;\n    for (var len = lit1.length, i = 0; i < len; i++) {\n      if (!Fay$$equal(lit1[i], lit2[i])) return false;\n    }\n    return true;\n  } else if (lit1 instanceof Fay$$Cons && lit2 instanceof Fay$$Cons) {\n    do {\n      if (!Fay$$equal(lit1.car,lit2.car))\n        return false;\n      lit1 = Fay$$_(lit1.cdr), lit2 = Fay$$_(lit2.cdr);\n      if (lit1 === null || lit2 === null)\n        return lit1 === lit2;\n    } while (true);\n  } else if (typeof lit1 == 'object' && typeof lit2 == 'object' && lit1 && lit2 &&\n             lit1.instance === lit2.instance) {\n    for(var x in lit1) {\n      if(!Fay$$equal(lit1[x],lit2[x]))\n        return false;\n    }\n    return true;\n  } else {\n    return false;\n  }\n}\n\n// Built-in ==.\nfunction Fay$$eq(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$equal(x,y);\n    });\n  };\n}\n\nfunction Fay$$eq$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$equal(x,y);\n  });\n\n}\n\n// Built-in /=.\nfunction Fay$$neq(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return !(Fay$$equal(x,y));\n    });\n  };\n}\n\n// Built-in /=.\nfunction Fay$$neq$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return !(Fay$$equal(x,y));\n  });\n\n}\n\n// Built-in >.\nfunction Fay$$gt(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) > Fay$$_(y);\n    });\n  };\n}\n\n// Built-in >.\nfunction Fay$$gt$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) > Fay$$_(y);\n  });\n\n}\n\n// Built-in <.\nfunction Fay$$lt(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) < Fay$$_(y);\n    });\n  };\n}\n\n\n// Built-in <.\nfunction Fay$$lt$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) < Fay$$_(y);\n  });\n\n}\n\n\n// Built-in >=.\nfunction Fay$$gte(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) >= Fay$$_(y);\n    });\n  };\n}\n\n// Built-in >=.\nfunction Fay$$gte$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) >= Fay$$_(y);\n  });\n\n}\n\n// Built-in <=.\nfunction Fay$$lte(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) <= Fay$$_(y);\n    });\n  };\n}\n\n// Built-in <=.\nfunction Fay$$lte$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) <= Fay$$_(y);\n  });\n\n}\n\n// Built-in &&.\nfunction Fay$$and(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) && Fay$$_(y);\n    });\n  };\n}\n\n// Built-in &&.\nfunction Fay$$and$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) && Fay$$_(y);\n  });\n  ;\n}\n\n// Built-in ||.\nfunction Fay$$or(x){\n  return function(y){\n    return new Fay$$$(function(){\n      return Fay$$_(x) || Fay$$_(y);\n    });\n  };\n}\n\n// Built-in ||.\nfunction Fay$$or$36$uncurried(x,y){\n\n  return new Fay$$$(function(){\n    return Fay$$_(x) || Fay$$_(y);\n  });\n\n}\n\n/*******************************************************************************\n * Mutable references.\n */\n\n// Make a new mutable reference.\nfunction Fay$$Ref(x){\n  this.value = x;\n}\n\n// Write to the ref.\nfunction Fay$$writeRef(ref,x){\n  ref.value = x;\n}\n\n// Get the value from the ref.\nfunction Fay$$readRef(ref){\n  return ref.value;\n}\n\n/*******************************************************************************\n * Dates.\n */\nfunction Fay$$date(str){\n  return Date.parse(str);\n}\n\n/*******************************************************************************\n * Data.Var\n */\n\nfunction Fay$$Ref2(val){\n  this.val = val;\n}\n\nfunction Fay$$Sig(){\n  this.handlers = [];\n}\n\nfunction Fay$$Var(val){\n  this.val = val;\n  this.handlers = [];\n}\n\n// Helper used by Fay$$setValue and for merging\nfunction Fay$$broadcastInternal(self, val, force){\n  var handlers = self.handlers;\n  var exceptions = [];\n  for(var len = handlers.length, i = 0; i < len; i++) {\n    try {\n      force(handlers[i][1](val), true);\n    } catch (e) {\n      exceptions.push(e);\n    }\n  }\n  // Rethrow the encountered exceptions.\n  if (exceptions.length > 0) {\n    console.error(\"Encountered \" + exceptions.length + \" exception(s) while broadcasing a change to \", self);\n    for(var len = exceptions.length, i = 0; i < len; i++) {\n      (function(exception) {\n        setTimeout(function() { throw exception; }, 0);\n      })(exceptions[i]);\n    }\n  }\n}\n\nfunction Fay$$setValue(self, val, force){\n  if (self instanceof Fay$$Ref2) {\n    self.val = val;\n  } else if (self instanceof Fay$$Var) {\n    self.val = val;\n    Fay$$broadcastInternal(self, val, force);\n  } else if (self instanceof Fay$$Sig) {\n    Fay$$broadcastInternal(self, val, force);\n  } else {\n    throw \"Fay$$setValue given something that's not a Ref2, Var, or Sig\"\n  }\n}\n\nfunction Fay$$subscribe(self, f){\n  var key = {};\n  self.handlers.push([key,f]);\n  var searchStart = self.handlers.length - 1;\n  return function(_){\n    for(var i = Math.min(searchStart, self.handlers.length - 1); i >= 0; i--) {\n      if(self.handlers[i][0] == key) {\n        self.handlers = self.handlers.slice(0,i).concat(self.handlers.slice(i+1));\n        return;\n      }\n    }\n    return _; // This variable has to be used, otherwise Closure\n              // strips it out and Fay serialization breaks.\n  };\n}\n"
