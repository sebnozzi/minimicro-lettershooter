import "listUtil"

onMM10 = (version.buildDate.indexOf("2021") == 0)

clear

text.color = color.silver
text.row = 15

wordPool = [
"break",
"continue",
"else",
"end",
"for",
"function",
"if",
"in",
"isa",
"new",
"null",
"then",
// "repeat", // not used currently - reserved for future use
"return",
"while",
"and",
"or",
"not",
"true",
"false"]

bulletSpeed = 500
asteroidSpeedRange = [100,100]
starSpeed = [20,40,80]

leftBoundary = 30
rightBoundary = 960-360
textColumn = 44

initialLives = 3
initialEnergy = 100
missReduces = 20
crashReduces = 20

// Define displays 

spr = display(4)

if display(2).mode != displayMode.pixel then
	display(2).mode = displayMode.pixel
end if

overlay = display(2)
overlay.clear color.clear

// Main Loop

mainLoop = function()	
	Sounds.init
	UI.drawAndCaptureImages
	UI.drawScreen
	
	Stars.init
	Stars.show
	
	Fighter.init
	Fighter.show
	
	WordGame.start
	UI.drawLivesAndEnergy
	
	while true
		if key.pressed("right") then Fighter.move("right")
		if key.pressed("left") then Fighter.move("left")
		if key.pressed("up") then Fighter.move("up")
		if key.pressed("down") then Fighter.move("down")
		if key.available then 
			k = key.get
			if k == " " then Fighter.shoot
			if k == "q" then exit
		end if
		
		// Process objects
		Bullets.update
		Asteroids.update
		Stars.update
		Fighter.update
		
		yield
	end while	
end function

// Game logic

WordGame = {}
WordGame.nonWordLetterCount = 6
WordGame.letterPool = []
WordGame.slots = []
WordGame.missed = []
WordGame.word = ""
WordGame.guessedWords = []
WordGame.startTime = time
WordGame.lives = initialLives
WordGame.energy = initialEnergy

WordGame.start = function()
	self.chooseRandomWord
	self.printSlots
end function

WordGame.wordPool = function()
	pool = []
	for word in wordPool
		pool.push word.upper
	end for
	return pool
end function

WordGame.chooseRandomWord = function()
	// Choose a not-yet-guessed word
	self.word = self.wordPool.any
	while self.guessedWords.contains(self.word)
		self.word = self.wordPool.any
	end while
	
	self.slots = []
	self.missed = []
	self.nonWordLetters = []
	for letter in self.word 
		if isAlpha(letter) then
			self.slots.push "_"
		else
			self.slots.push letter	
		end if		
	end for
	self.setNonWordLetters
	self.updateLetterPool
end function

WordGame.setNonWordLetters = function()
	// Add some non-word letters
	wordLetters = self.word.values
	self.nonWordLetters = []
	
	for i in range(1,self.nonWordLetterCount)
		r = randomLetter
		while wordLetters.contains(r)
			r = randomLetter
		end while
		self.nonWordLetters.push r
	end for
end function

WordGame.updateLetterPool = function()
	pool = []
	
	// Add twice to increase chances and make easier
	// (remove to make harder)
	for i in range(1,2)
		// Choose from the letters of the word
		for c in self.word
			// Add letter if not already guessed
			if not self.slots.contains(c) and isAlpha(c) then pool.push c
		end for
	end for
	
	// Add from non-word-letters, but only if not yet guessed
	for c in self.nonWordLetters
		if not self.missed.contains(c) then
			pool.push c
		end if
	end for
	
	self.letterPool = pool
end function

WordGame.asteroidLetter = function()
	return self.letterPool.any
end function

WordGame.printSlots = function(wordGuessed=false)
	txt = ""
	for c in self.slots
		txt = txt + c + " "
	end for
	UI.printText ""
	if wordGuessed then 
		UI.printText txt, color.yellow
	else
		UI.printText txt
	end if
	UI.printText ""
end function

WordGame.playLetter = function(letter)
	idx = 0
	matchFound = false
	for c in self.word 
		slotValue = self.slots[idx]
		if c == letter then
			matchFound = true
			self.slots[idx] = letter
		end if
		idx = idx + 1
	end for
	
	if matchFound then
		self.onLetterMatch
	else
		self.onLetterMiss(letter)
	end if	
	
	self.updateLetterPool
end function

WordGame.onLetterMiss = function(letter)
	Sounds.letterMiss
	UI.printText "# MISS: " + letter
	self.missed.push letter
	self.reduceEnergy	
end function

WordGame.reduceEnergy = function(reason="miss")
	amountToReduce = missReduces
	if reason == "crash" then amountToReduce = crashReduces
	self.energy = self.energy - amountToReduce
	if self.energy == 0 then
		self.reduceLives
	end if
	UI.drawLivesAndEnergy
end function

WordGame.reduceLives = function()
	self.lives = self.lives - 1
	if self.lives == 0 then
		self.gameOver
	else
		self.energy = initialEnergy
	end if
end function

WordGame.gameOver = function()
	UI.drawLivesAndEnergy
	UI.printCenteredMsg "GAME OVER"
	exit
end function

WordGame.onLetterMatch = function()
	if not self.slots.contains("_") then
		self.printSlots(true)
		Asteroids.removeAll
		Asteroids.nextAddTs = time + 3
		self.onWordMatch
	else
		self.printSlots(false)
		Sounds.letterGuess
	end if
end function

WordGame.onWordMatch = function()
	self.guessedWords.push self.word
	if self.guessedWords.len == wordPool.len then
		self.onGameWon	
	else
		Sounds.wordGuess
		wordsToGo = wordPool.len - self.guessedWords.len
		UI.printText self.encouragement
		UI.printText "NEXT! (" + wordsToGo + " to go)"
		self.start
	end if	
end function

WordGame.encouragement = function()
	phrases = [
	"Excellent",
	"Great!",
	"That's right!",
	"Keep going!",
	"Well done"]
	return phrases.any
end function

WordGame.onGameWon = function()
	Sounds.gameWon
	UI.printCenteredMsg "YOU WIN!"
	
	UI.printText ""
	secondsPlayed = floor(time - self.startTime)
	UI.printText "Won in " + secondsPlayed + " seconds"
	exit
end function

// UI Manager

UI = {}
UI.bulletImg = null
UI.asteroidImg = null
UI.heartImg = null
UI.charImages = []
UI.starImages = []

UI.leftBoundary = leftBoundary
UI.rightBoundary = rightBoundary
UI.upBoundary = 600
UI.downBoundary = 40

UI.drawAndCaptureImages = function()
	gfx.clear
	self.drawAndCaputureBullet
	self.drawAndCaptureLetters
	self.drawAndCaptureAsteroid
	self.drawAndCaptureStars
	self.heartImg = file.loadImage("/sys/pics/Heart.png")
	gfx.clear
end function

UI.drawAndCaputureBullet = function()
	gfx.clear
	gfx.fillRect 0,0,5,30,"#FF9D21FF"
	self.bulletImg = gfx.getImage(0,0,5,30)	
end function

UI.drawAndCaptureLetters = function()
	gfx.clear
	charImages = []
	lx = 0
	for c in range(65,90)
		gfx.print char(c),lx*24+2,-2,color.gray,"large"
		gfx.print char(c),lx*24,0,color.white,"large"
		charImg = gfx.getImage(lx*24,2,24,30)
		charImages.push charImg
		lx = lx + 1
	end for	
	self.charImages = charImages
end function

UI.drawAndCaptureAsteroid = function()
	gfx.clear
	gfx.fillEllipse 0,0,70,70,color.rgb(220,220,220)
	img = gfx.getImage(0,0,70,70)
	self.asteroidImg = img
end function

UI.drawAndCaptureStars = function()
	width = UI.rightBoundary - UI.leftBoundary
	height = 640
	
	drawAndCaptureLayer = function(starCount,radius)
		gfx.clear
		for i in range(1,starCount)
			x = rnd * width
			y = rnd * height
			gfx.fillEllipse x,y,radius,radius,color.silver
		end for
		UI.starImages.push gfx.getImage(0,0,width,height)
	end function
	
	// Layer 1
	drawAndCaptureLayer(200,2)
	// Layer 2
	drawAndCaptureLayer(50,4)
	// Layer 3
	drawAndCaptureLayer(10,8)
	
end function

UI.drawScreen = function()
	// Some definitions
	areaColor = "#000041"
	leftLimit = self.leftBoundary
	rightLimit = self.rightBoundary
	// Draw areas
	gfx.fillRect 0,0,leftLimit,640,areaColor
	gfx.fillRect rightLimit,0,960,640,areaColor
	// Draw lines
	gfx.line leftLimit,0,leftLimit,640,color.silver,4
	gfx.line rightLimit,0,rightLimit,640,color.silver,4		
end function

UI.printText = function(txt,txtColor)
	if txtColor then
		text.color = txtColor
	else
		text.color = color.silver
	end if
	text.column = textColumn; print txt
end function

UI.drawLivesAndEnergy = function()
	width = rightBoundary-leftBoundary
	height = 30
	
	overlay.fillRect leftBoundary+10,600,width-20,height,color.clear
	
	energy = WordGame.energy
	energyColor = color.green
	
	if energy <= 50 then energyColor = color.yellow
	if energy <= 20 then energyColor = color.orange
	
	overlay.fillRect rightBoundary-130,600,100,25,color.black	
	overlay.fillRect rightBoundary-130,600,WordGame.energy,25,energyColor
	overlay.drawRect rightBoundary-130,600,100,25,color.black,4
	overlay.drawRect rightBoundary-130,600,100,25,color.silver,2
	
	if WordGame.lives then
		for lifeNr in range(1,WordGame.lives)
			x = rightBoundary-140 - lifeNr * 30
			overlay.drawImage self.heartImg,x,588,30,51	
		end for
	end if
end function

UI.printCenteredMsg = function(msg)
	overlay.print msg,leftBoundary+200+2,300-2,color.black,"large"
	overlay.print msg,leftBoundary+200,300,color.silver,"large"
end function

// Stars

Stars = {}
Stars.layersA = []
Stars.layersB = []
Stars.lastUpdateTs = 0
Stars.layerRange = function()
	return range(0, UI.starImages.len-1)
end function
Stars.init = function()
	for layerIdx in self.layerRange
		image = UI.starImages[layerIdx]
		
		layerA = new Sprite
		layerA.image = image
		layerA.x = UI.leftBoundary + image.width / 2
		layerA.y = 640 / 2
		
		layerB = new Sprite
		layerB.image = image
		layerB.x = layerA.x
		layerB.y = 640 + image.height / 2
		
		self.layersA.push layerA
		self.layersB.push layerB	
	end for	
end function
Stars.show = function()
	for layerIdx in self.layerRange
		spr.sprites.push self.layersA[layerIdx]
		spr.sprites.push self.layersB[layerIdx]	
	end for
end function	
Stars.update = function()
	deltaTs = time - self.lastUpdateTs
	for layerIdx in self.layerRange
		speed = starSpeed[layerIdx]
		height = UI.starImages[layerIdx].height
		layerA = self.layersA[layerIdx]
		layerB = self.layersB[layerIdx]
		layerA.y = layerA.y - speed * deltaTs
		layerB.y = layerB.y - speed * deltaTs
		if (layerA.y + height / 2) < 0 then
			layerA.y = 640 + height / 2
		end if
		if (layerB.y + height / 2) < 0 then 
			layerB.y = 640 + height / 2
		end if
	end for	
	self.lastUpdateTs = time
end function

// Asteroids
Asteroids = {}
Asteroids.asteroids = []
Asteroids.nextAddTs = time - 5
Asteroids.tintColors = [
// redish
color.rgb(255,100,100),
// blueish
color.rgb(90,90,255), 
// greenish
color.rgb(100,255,100),
// violet-like
"#FF8CFF"]
Asteroids.lastUpdateTs = 0

Asteroids.update = function()
	a = self.processHit(Fighter)
	if a then 
		UI.printText "# CRASH!"
		Sounds.crash
		Fighter.animateCrash
		WordGame.reduceEnergy
	end if
	self.moveDown
	self.addIfDueTime
	self.lastUpdateTs = time
end function

Asteroids.processHit = function(other)
	notHit = []
	asteroidHit = null
	
	// See if an asteroid has been hit
	for a in self.asteroids
		if not a.hit then
			// Check collision with fighter
			if a.overlaps(other) then
				asteroidHit = a
				a.hit = true
				a.hide
			else
				notHit.push a
			end if
		end if
	end for
	
	self.asteroids = notHit
	
	return asteroidHit
end function

Asteroids.moveDown = function()
	onScreen = []
	
	deltaTs = time - self.lastUpdateTs
	
	for a in self.asteroids 
		a.moveDown deltaTs
		if a.y < 10 then
			a.hide
		else
			onScreen.push a
		end if
	end for
	
	self.asteroids = onScreen
end function

Asteroids.addIfDueTime = function()
	ts = time
	margin = 50
	if ts > self.nextAddTs then
		width = UI.rightBoundary - UI.leftBoundary - margin * 2
		x = rnd * width + UI.leftBoundary + margin
		
		a = new Asteroid
		letter = WordGame.asteroidLetter
		a.init(letter,x,600)
		a.speed = asteroidSpeedRange[0] + rnd * asteroidSpeedRange[1]
		
		a.setTint(self.tintColors.any)
		a.show
		self.asteroids.push a
		
		self.nextAddTs = ts + rnd * 3
	end if
end function

Asteroids.removeAll = function()
	for a in self.asteroids
		a.hide
	end for
	self.asteroids = []
end function

// Define Asteroid class

Asteroid = new Sprite
Asteroid.letter = ""
Asteroid.baseSpr = null
Asteroid.letterSpr = null
Asteroid.hit = false
Asteroid.init = function(letter,x,y)
	self.letter = letter
	
	self.baseSpr = new Sprite
	self.baseSpr.x = x
	self.baseSpr.y = y
	self.baseSpr.image = UI.asteroidImg
	self.baseSpr.tint = color.rgb(255,160,160)
	
	letterIdx = letter.code - "A".code
	self.letterSpr = new Sprite
	self.letterSpr.x = x
	self.letterSpr.y = y
	self.letterSpr.image = UI.charImages[letterIdx]
	self.letterSpr.scale = 1.5
	
	self.baseSpr.localBounds = boundsFromImg(UI.asteroidImg)
end function
Asteroid.x = function()
	return self.baseSpr.x
end function
Asteroid.y = function()
	return self.baseSpr.y
end function
Asteroid.speed = 1
Asteroid.moveDown = function(deltaTs)
	newY = self.y - self.speed * deltaTs
	self.move(self.x, newY)
end function
Asteroid.show = function()
	spr.sprites.push self.baseSpr
	spr.sprites.push self.letterSpr
end function
Asteroid.hide = function()
	removeSprite(self.baseSpr)
	removeSprite(self.letterSpr)
end function
Asteroid.move = function(x,y)
	self.baseSpr.x = x
	self.baseSpr.y = y
	self.letterSpr.x = x
	self.letterSpr.y = y
end function
Asteroid.overlaps = function(other)
	return self.baseSpr.overlaps(other)
end function
Asteroid.setTint = function(tintColor)
	self.baseSpr.tint = tintColor
end function

// Define Bullet class

Bullet = new Sprite
Bullet.x = 0
Bullet.y = 0
Bullet.hit = false

Bullet.init = function(x,y)
	self.x = x
	self.y = y
	self.image = UI.bulletImg
	self.localBounds = boundsFromImg(UI.bulletImg)	
end function

Bullet.hide = function()
	removeSprite self
end function

// Define Fighter

Fighter = new Sprite

Fighter.leftBoundary = 0
Fighter.rightBoundary = 0
Fighter.upBoundary = UI.upBoundary
Fighter.downBoundary = UI.downBoundary
Fighter.width = 0
Fighter.crashAnimationEnd = 0

Fighter.init = function()
	fighterImg = file.loadImage("/sys/pics/Fighter.png")
	self.image = fighterImg
	self.localBounds = boundsFromImg(fighterImg)
	self.scale = 0.5
	if not onMM10 then self.rotation = 90
	self.width = self.image.width * self.scale
	self.leftBoundary = UI.leftBoundary + self.width / 2 + 20
	self.rightBoundary = UI.rightBoundary - self.width / 2 - 20
end function

Fighter.show = function()
	self.x = UI.leftBoundary + (UI.rightBoundary - UI.leftBoundary) / 2
	self.y = UI.downBoundary
	spr.sprites.push self	
end function

Fighter.move = function(dir)
	if dir == "right" then self.x = self.x + 10
	if dir == "left" then self.x = self.x - 10
	if dir == "up" then self.y = self.y + 10
	if dir == "down" then self.y = self.y - 10
	self.adjustPosition
end function

Fighter.adjustPosition = function()
	if self.x < self.leftBoundary then self.x = self.leftBoundary
	if self.x > self.rightBoundary then self.x = self.rightBoundary
	if self.y > self.upBoundary then self.y = self.upBoundary
	if self.y < self.downBoundary then self.y = self.downBoundary
end function

Fighter.shoot = function()
	Sounds.shoot
	Bullets.addBullet self.x, self.y + 70
end function

Fighter.animateCrash = function()
	self.crashAnimationEnd = time + 0.7
end function

Fighter.update = function()
	if time < self.crashAnimationEnd then
		self.tint = color.pink
	else
		self.tint = color.white
	end if
end function

// Bullets

Bullets = {}
Bullets.bullets = []
Bullets.lastUpdateTs = 0

Bullets.addBullet = function(bulletX, bulletY)
	bullet = new Bullet
	bullet.init(bulletX, bulletY)	
	spr.sprites.push bullet
	self.bullets.push bullet
end function

Bullets.update = function()
	onScreen = []
	deltaTs = time - self.lastUpdateTs
	for bullet in self.bullets
		if not bullet.hit then
			bullet.y = bullet.y + deltaTs * bulletSpeed
			if bullet.y > 600 then
				bullet.hide
			else 
				// Check collision with asteroid
				asteroidHit = Asteroids.processHit(bullet)
				if asteroidHit then
					letter = asteroidHit.letter
					WordGame.playLetter(letter)
					bullet.hit = true
					bullet.hide
				else
					onScreen.push bullet
				end if
			end if
		end if
	end for
	self.bullets = onScreen
	self.lastUpdateTs = time
end function

// Sounds

Sounds = {}
Sounds.init = function()
	self.crashSnd = file.loadSound("/sys/sounds/airburst.wav")
	self.shootSnd = file.loadSound("/sys/sounds/pew.wav")
	self.missSnd = file.loadSound("/sys/sounds/hit.wav")
	self.letterGuessSnd = file.loadSound("/sys/sounds/ting.wav")
	self.wordGuessSnd = file.loadSound("/sys/sounds/bling.wav")
	self.gameWonSnd = file.loadSound("/sys/sounds/fanfare.wav")
end function
Sounds.crash = function()
	self.crashSnd.play
end function
Sounds.shoot = function()
	self.shootSnd.play 0.5
end function
Sounds.letterMiss = function()
	self.missSnd.play 0.7
end function
Sounds.letterGuess = function()
	self.letterGuessSnd.play
end function
Sounds.wordGuess = function()
	self.wordGuessSnd.play 0.3
end function
Sounds.gameWon = function()
	self.gameWonSnd.play
end function

// Helper functions

boundsFromImg = function(img)
	bounds = new Bounds
	bounds.width = img.width
	bounds.height = img.height
	return bounds
end function

removeSprite = function(sprite)
	idx = spr.sprites.indexOf(sprite)
	if idx then spr.sprites.remove idx
end function

randomLetter = function()
	return char(rnd * ("Z".code + 1 - "A".code) + "A".code)
end function

isAlpha = function(ch)
	chUp = ch.upper
	return chUp >= "A" and chUp <= "Z"
end function

// Start program

mainLoop
