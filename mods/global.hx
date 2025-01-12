function onCreate()
{
    var sprite:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height);
    game.add(sprite);
}

function onUpdate(elapsed:Float)
{
    if (FlxG.keys.justPressed.F5) FlxG.resetState();
}