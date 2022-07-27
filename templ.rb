module Templ
	include ERB::Util
	def Render(templatename)
		content = File.read("./templates/#{templatename}")
		return ERB.new(content).result(binding)
	end

	def h(str)
		html_escape str
	end
end