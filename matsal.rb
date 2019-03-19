#
#
# Created by Martin Larsson 15_tek_cs
# martin.99.larsson@telia.com
# skip to the Window class for all the important code
#
#
Dir.chdir(File.dirname(__FILE__)) #File location fix

begin
	require 'gosu'
rescue LoadError
	puts "Gosu not installed! visit https://github.com/gosu/gosu/wiki for instructions"
	gets
	exit
end

begin
	require 'rubyXL'
rescue LoadError
	puts "rubyXL not installed! enter 'gem install rubyXL' into a console"
	gets
	exit
end
require 'date'

$closingTime = "13:30:00" 	        #the time the program should autosave and clear
$backColor = 0xff_38003a 		    #background color
$screenWidth = 1366 			    #screen resolution
$screenHeight = 768
$fullscreen = true	 			    #fullscreen toggle
$vipIDs = ["00000000ee", "0f03a9319c", "sod15046", "sodjebi", "sodjepr", "sod15030", "sod15095", "sod15019", "sod15023", "sod17049", "sod15045", "sod17042", "sod17020", "0f03b74a8d"]
# ^ vip ids for fancy colors ;)
$logo = Gosu::Image.new("logo.jpg") #ITG logo

#used to display names on the screen, scrolls down each time a new card is created
class Card
	attr_accessor :y
	def initialize(text, color = false)
		$grafixlist << self
		@text = text
		if color
			@color = 0xff_ff00ff
		else
			hue = Time.now.yday
			@color = Gosu::Color.from_hsv([0, hue, 360].sort[1], 1, 1)
		end
		@y = @realy = -30
		@x = 40 + $logo.width
		$grafixlist.each{|x| x.y += 64}
	end

	def draw
		$font.draw(@text, @x, @realy, 0, 1, 1, @color)
	end

	def update
		if (@realy - @y).abs > 0
			@realy += 4
		end
		#destroys itself when its offscreen
		if @realy > $screenHeight
			$grafixlist.delete(self)
		end
	end
end

#a popup created when a user tries to scan a card multiple times
class Popup
	attr_accessor :y
	def initialize(text, color)
		@text = text
		@color = color
		@width = $font.text_width(text)
		@x = 500 - @width / 2
		@posy = 500 - 30
		@y = 0
		$grafixlist << self
	end
	def draw
		Gosu::draw_rect(495 - @width / 2, @posy - 5, @width + 10, 70, 0xff_303030, 1)
		$font.draw(@text, @x, @posy, 2, 1, 1, @color)
	end

	def update
		@y += 0.1
		if @y > 40
			$grafixlist.delete(self)
		end
	end
end

class Window < Gosu::Window
	def initialize
		super($screenWidth, $screenHeight, $fullscreen) #Creates the window

		@time = "00:00:00" 						#On screen time, "hour:minute:second"
		@database = Hash.new("Okänd") #Database for all users, default to Okänd
		@personal = Hash.new(0) 	#Database if the user is a personal or not
		@haveEaten = [] 						#a list of people that have already eaten today

		@input = Gosu::TextInput.new 	#allows gosu to get keyboard(and scanner) input
		self.text_input = @input

		$font = Gosu::Font.new(60) #gosu font used for text on screen, 60 = pixel height of the text
		$grafixlist = [] #list of all objects on screen

		#loads all databases
		Dir[File.dirname(__FILE__) + '/databaser/*.xlsx'].each do |file|
			excel = RubyXL::Parser.parse(file)[0]
			firstRow = excel[0]
			isPersonal = firstRow[1].value.to_i
			excel.each do |row|
				next if row == firstRow
				if row
					id = row[0].value
					name = row[1].value
					@database[id] = name
					@personal[id] = isPersonal
				end
			end
		end
		#checks if there is a temp file, in case the program crashed / was wrongly terminated
		if File.file?("temp.txt")
			temp = File.open("temp.txt", "r")
			while line = temp.gets
				#reloads all temp saved ids
				@haveEaten << line.chomp
			end
			temp.close
			#creates cards from the last 10
			for id in @haveEaten.last(10) do
				Card.new(@database[id], $vipIDs.include?(id))
			end
		end
	end


	def update #called 60 times a second
		@time = Time.now.strftime("%H:%M:%S") #updates the time text
		if @time == $closingTime #if its closing time
			#saves, and waits a second to not rerun this multiple times on the same second
			save
			sleep(1)
		end
		$grafixlist.each{|x| x.update} #updates all objects on screen
	end

	def save #method to save and reset the list, called every day at $closingTime
		return if @haveEaten.size < 1
		#filename is current year + month
		fileName = Time.now.strftime("%Y-%B")

		#file for number of people that have eaten this day
		file = File.open(fileName + '.txt', "a")
		file.puts "#{Time.now.day}:\t#{@haveEaten.size}"
		file.close

		#file for how many times someone form the personal has eaten this month
		fileName += '-personal.xlsx'
		personal = Hash.new(0)
		excel = nil
		if File.file?(fileName)
			workbook = RubyXL::Parser.parse(fileName)
			excel = workbook[0]
			excel.each do |row|
				if row
					name = row[0].value
					amount = row[1].value
					personal[name] = amount.to_i
				end
			end
		else
			workbook = RubyXL::Workbook.new
			excel = workbook[0]
		end

		#loops trough all that have eaten and are personal
		for id in @haveEaten do
			if @personal[id] == 1
				#increments the hash amount by one
				name = @database[id]
				personal[name] = (personal[name] + 1)
			end
		end

		personal.each.with_index do |person, index|
			excel.add_cell(index, 0, person[0])
			excel.add_cell(index, 1, person[1])
		end
		File.delete(fileName) if File.file?(fileName)
		workbook.write(fileName)
		#clears lists, ready for a new day!
		@haveEaten = []
		$grafixlist = []
		File.delete("temp.txt") if File.file?("temp.txt")
	end

	#draws the clock and all objects
	#i could draw so many memes here...
	def draw
		Gosu::draw_rect(0, 0, $screenWidth, $screenHeight, $backColor) #background
		$logo.draw(20, 20, 0)
		$font.draw(@time, 20, 30 + $logo.height, 0) #clock
		$font.draw('#' + @haveEaten.size.to_s, 20, 40 + $font.height + $logo.height, 1) #number of people that have eaten
		$grafixlist.each{|x| x.draw} #all objects (popups / names)
	end

	#gets called everytime a non-character button is pressed
	def button_down(id)
		if id == Gosu::KbReturn
			#enter was pressed (by the scanner)
			#gets the text and clears the input field
			input = @input.text.chomp.downcase
			@input.text = ""
			#for manual shutoff, enter partybussen on a keyboard and press enter, still saves
			if input == "end"
				save
				close
				return
			end
			if @haveEaten.include? input
				#notifies the user that you have already eaten
				Popup.new("Du har redan ätit!", 0xff_ff0000)
			else
				#adds user to the eaten list and displays the name
				@haveEaten << input
				name = @database[input]
				#records the id if it is unknown
				if name == "Okänd"
					File.open("Okända.txt", "a") {|f| f.puts input}
				else
					File.open("temp.txt", "a") {|f| f.puts input}
				end
				Card.new(name, $vipIDs.include?(input))
				#adds id to the temp file
			end
		end
	end
end

Window.new.show
