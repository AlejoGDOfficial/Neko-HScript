var image:FlxSprite;

function onCreate()
{
    FlxG.sound.play(Paths.sound('flixel'));

    image = new FlxSprite().loadGraphic(Paths.image('haxeFlixel'));
    add(image);
}

var currentTime:Float = 0;

function onUpdate(elapsed:Float)
{
    currentTime += elapsed;

    image.x = FlxG.width / 2 - image.width / 2 + Math.sin(currentTime) * 300;
    image.y = FlxG.height / 2 - image.height / 2 + Math.cos(currentTime * 4) * 100;
}