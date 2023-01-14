# tmpl.rb

class Templ
	include ERB::Util

	def render()
		content = File.read("./templates/#{self.class::TEMPLATENAME}")
		return ERB.new(content).result(binding)
	end

	def h(str)
		html_escape str
	end
end