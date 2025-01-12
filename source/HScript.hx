package;

import flixel.FlxBasic;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;

class HScript extends Iris
{
	public var filePath:String;
	public var modFolder:String;

	public var origin:String;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false)
	{
		if (file == null)
			file = '';

		filePath = file;

		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
		}

		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		
		this.varsToBring = varsToBring;
		super(scriptThing, new IrisConfig(scriptName, false, false));
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = FlxG.state;
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		
		if (!manualRun) {
			var _active:Bool = tryRunning();
			if (_active == false)
				return;
		}
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			if (FlxG.state != null)
				trace('[$origin]: $x', FlxColor.YELLOW);
			Iris.logLevel(WARN, x, pos);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			if (FlxG.state != null)
				trace('[$origin]: $x', FlxColor.ORANGE);

			Iris.logLevel(ERROR, x, pos);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			if (FlxG.state != null)
				trace('[$origin]: $x', FlxColor.RED);
			Iris.logLevel(FATAL, x, pos);
		}
	}

	function tryRunning(destroyOnError:Bool = true):Bool {
		try {
			preset();
			execute();
			return true;
		} catch(e:haxe.Exception) {
			if(destroyOnError) this.destroy();
			throw e;
			return false;
		}
		return false;
	}

	var varsToBring(default, set):Any = null;
	override function preset() {
		super.preset();

		set('Type', Type);
		set('File', File);
		set('FileSystem', FileSystem);
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);

		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			trace(text, color);
		});

		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		set('gamepadJustPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});

		set('gamepadPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});

		set('gamepadReleased', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic) {
				var msg:String = e.message.substr(0, e.message.indexOf('\n'));
				if(FlxG.state != null) trace('$origin - $msg', FlxColor.RED);
				else trace('$origin - $msg');
			}
		});

		set('this', this);
		set('game', FlxG.state);
	}

	public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):IrisCall {
		if (funcToRun == null) return null;

		if(!exists(funcToRun)) {
			trace(origin + ' - No function named: $funcToRun', FlxColor.RED);
			return null;
		}

		try
		{
			final callValue:IrisCall = call(funcToRun, funcArgs);
			return callValue;
		} catch(e:Dynamic) {
			trace('ERROR ${funcToRun}: $e');
		}

		return null;
	}

	override public function destroy()
	{
		origin = null;
		super.destroy();
	}

	function set_varsToBring(values:Any) {
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				if(exists(key.trim()))
					interp.variables.remove(key.trim());

		if (values != null)
		{
			for (key in Reflect.fields(values))
			{
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}

class CustomInterp extends crowplexus.hscript.Interp
{
	public var parentInstance:Dynamic;
	public function new()
	{
		super();
	}

	override function resolve(id: String): Dynamic {
		if (locals.exists(id)) {
			var l = locals.get(id);
			return l.r;
		}

		if (variables.exists(id)) {
			var v = variables.get(id);
			return v;
		}

		if (imports.exists(id)) {
			var v = imports.get(id);
			return v;
		}

		if(parentInstance != null) {
			var v = Reflect.getProperty(parentInstance, id);
			return v;
		}

		error(EUnknownVariable(id));

		return null;
	}
}