package;

import crowplexus.iris.Iris;

class PlayState extends FlxState
{
	var hscriptArray:Array<HScript> = [];

	override public function create()
	{
		initHScript('mods/global.hx');

		setOnHScript('this', this);
		setOnHScript('game', FlxG.state);

		callOnHScript('onCreate');

		super.create();

		callOnHScript('onCreatePost');
	}

	override public function update(elapsed:Float)
	{
		callOnHScript('onUpdate', [elapsed]);

		super.update(elapsed);

		callOnHScript('onUpdatePost', [elapsed]);
	}

	override public function destroy()
	{
		callOnHScript('onDestroy');

		for (script in hscriptArray)
			if(script != null)
			{
				var ny:Dynamic = script.get('onDestroy');
				if(ny != null && Reflect.isFunction(ny)) ny();
				script.destroy();
			}

		hscriptArray = null;

		super.destroy();
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			newScript.call('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		} catch(e:Dynamic) {
			trace('ERROR ON LOADING ($file) - $e', FlxColor.RED);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if(newScript != null)
				newScript.destroy();
		}
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) 
	{
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:String = '';

		if (exclusions == null) exclusions = new Array();
		if (excludeValues == null) excludeValues = new Array();

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;

		for(script in hscriptArray)
		{
			@:privateAccess
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			try
			{
				var callValue = script.call(funcToCall, args);
				var myValue:Dynamic = callValue.returnValue;

				if(!excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if(myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			} catch(e:Dynamic) {
				trace('ERROR (${script.origin}: $funcToCall) - $e', FlxColor.RED);
			}
		}

		return returnVal;
	}
}
