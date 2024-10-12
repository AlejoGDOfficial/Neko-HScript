package states;

import flixel.FlxState;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.display.StageScaleMode;

import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;

import backend.ScriptingUtils;
import backend.HScript;

import tea.SScript;

class ScriptState extends FlxState
{
    public static var targetFileName:String; 

    public function new(scriptName:String) 
    {
        super();

        targetFileName = scriptName;
    }

	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

    public static var instance:ScriptState;

	public var hscriptArray:Array<HScript> = [];
	public var instancesExclude:Array<String> = [];

	var keysPressed:Array<Int> = [];
	private var keysArray:Array<String>;

    override public function create()
    {
        instance = this;
		
		if (targetFileName == 'configGame')
		{
			startHScriptsNamed('scripts/config/config.hx');
		} else {
			startHScriptsNamed('scripts/states/' + targetFileName + '.hx');
			startHScriptsNamed('scripts/states/global.hx');
		}

		callOnScripts('onCreatePost');

        super.create();
    }

    override public function update(elapsed:Float)
    {
		callOnScripts('onUpdate', [elapsed]);

		callOnScripts('onUpdatePost', [elapsed]);

        super.update(elapsed);
    }

	private function keyPressed(key:Int)
	{
		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == ScriptingUtils.Function_Stop) return;

		if(!keysPressed.contains(key)) keysPressed.push(key);

		callOnScripts('onKeyPress', [key]);
	}

	private function keyReleased(key:Int)
	{
		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == ScriptingUtils.Function_Stop) return;

		callOnScripts('onKeyRelease', [key]);
	}

	override function destroy() {
		for (script in hscriptArray)
			if(script != null)
			{
				script.call('onDestroy');
				script.destroy();
			}

		hscriptArray = null;
	}

	public function startHScriptsNamed(scriptFile:String)
	{
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);

		if(FileSystem.exists(scriptToLoad))
		{
			if (SScript.global.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		try
		{
			var newScript:HScript = new HScript(null, file);
			if(newScript.parsingException != null)
			{
				trace('ERROR ON LOADING: ${newScript.parsingException.message}');
				newScript.destroy();
				return;
			}

			hscriptArray.push(newScript);
			if(newScript.exists('onCreate'))
			{
				var callValue = newScript.call('onCreate');
				if(!callValue.succeeded)
				{
					for (e in callValue.exceptions)
					{
						if (e != null)
						{
							var len:Int = e.message.indexOf('\n') + 1;
							if(len <= 0) len = e.message.length;
								trace('ERROR ($file: onCreate) - ${e.message.substr(0, len)}');
						}
					}

					newScript.destroy();
					hscriptArray.remove(newScript);
					trace('failed to initialize tea interp!!! ($file)');
				}
				else trace('initialized tea interp successfully: $file');
			}

		}
		catch(e)
		{
			var len:Int = e.message.indexOf('\n') + 1;
			if(len <= 0) len = e.message.length;
			trace('ERROR - ' + e.message.substr(0, len));
			var newScript:HScript = cast (SScript.global.get(file), HScript);
			if(newScript != null)
			{
				newScript.destroy();
				hscriptArray.remove(newScript);
			}
		}
	}

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = ScriptingUtils.Function_Continue;
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [ScriptingUtils.Function_Continue];

		var result:Dynamic = null;
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = ScriptingUtils.Function_Continue;

		if(exclusions == null) exclusions = new Array();
		if(excludeValues == null) excludeValues = new Array();
		excludeValues.push(ScriptingUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;
		for(i in 0...len) {
			var script:HScript = hscriptArray[i];
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var myValue:Dynamic = null;
			try {
				var callValue = script.call(funcToCall, args);
				if(!callValue.succeeded)
				{
					var e = callValue.exceptions[0];
					if(e != null)
					{
						var len:Int = e.message.indexOf('\n') + 1;
						if(len <= 0) len = e.message.length;
						trace('ERROR (${callValue.calledFunction}) - ' + e.message.substr(0, len));
					}
				}
				else
				{
					myValue = callValue.returnValue;

					// compiler fuckup fix
					final stopHscript = myValue == ScriptingUtils.Function_StopHScript;
					final stopAll = myValue == ScriptingUtils.Function_StopAll;
					if((stopHscript || stopAll) && !excludeValues.contains(myValue) && !ignoreStops)
					{
						returnVal = myValue;
						break;
					}

					if(myValue != null && !excludeValues.contains(myValue))
						returnVal = myValue;
				}
			}
			catch (e:Dynamic) {}
		}

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			if(!instancesExclude.contains(variable))
				instancesExclude.push(variable);
			script.set(variable, arg);
		}
	}

	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		return new FlxRuntimeShader();

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
	}

    public function switchToScriptState(name:String)
    {
		FlxG.switchState(new ScriptState(name));
    }

	public function resetScriptState()
	{
		switchToScriptState(targetFileName);
	}
}