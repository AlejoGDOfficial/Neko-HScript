package states;

class ConfigState extends FlxState
{
    override function create()
    {
        FlxG.switchState(new ScriptState('configGame'));

        super.create();
    }
}