#!/usr/bin/ruby

require 'Qt'
require 'active_support/all'

PANEL_HEIGHT = 500
DISTANCE = 19
LINE_WIDTH = 5
DIVISIONS = 10
FULL_CAPACITY = 700
MAX_CAPACITY = 750

class CodeWidgetSettings < Hash
  def colors
    {
      :background => Qt::Color.new(255, 255, 255),
      :default_font => Qt::Color.new(0,0,0),
      :class_def => Qt::Color.new(255,255,128),
      :focus => Qt::Color.new(128,128,128),
      :constant => Qt::Color.new(200,0,0),
      :identifier => Qt::Color.new(0,200,0)
    }
  end
  
  def node
    {
      :margin => 2
    }
  end
  
  def font_family
    "Courier"
  end
  
  def font_size
    12
  end
  
  def font_weight
    Qt::Font::Bold
  end
  
  def font_italic
    false
  end
end



class NodeFactory
  def self.configure(top_level_widget, settings)
    @@top_level_widget = top_level_widget
    @@settings = settings
  end
  
  def self.produce(type = Node)
    cmp = type.new
    cmp.settings = @@settings
    cmp.top_level_widget = @@top_level_widget
    cmp.setText("")
    cmp
  end
end

class Node
  attr_accessor :w, 
                :h, 
                :text, 
                :children, :slots,
                :parent,
                :settings,
                :font,
                :top_level_widget,
                :slot_pos, :child_pos
                
  def initialize()
    self.children = []
    self.slots = []
    self.slot_pos = -1
    self.child_pos = -1

  end
  
  def setText(text)
    self.text = text
    case text
      when "def "
        iden_slot = NodeFactory.produce(IdentifierNode)
        iden_slot.parent = self
        params_slot = NodeFactory.produce(ParamsNode)
        params_slot.parent = self
        self.slots = [iden_slot, params_slot]
        self.slot_pos = 0
        self.top_level_widget.activeNode = iden_slot
      when "class "
        new_slot = NodeFactory.produce(ConstantNode)
        new_slot.parent = self
        self.slots = [new_slot]
        self.slot_pos = 0
        self.top_level_widget.activeNode = new_slot
      when ""
        handle_back
      else
        self.slots = []
        self.slot_pos = -1

    end 
    self.text.strip!
    setFont()
    setDimensions()
  end
  
  def setFont
    self.font = Qt::Font.new(
      self.settings.font_family, 
      self.settings.font_size, 
      self.settings.font_weight,
      self.settings.font_italic
    )
  end
  
  def setDimensions
    fontMetrics = Qt::FontMetricsF.new(self.font)
    rect = fontMetrics.boundingRect(self.text)
    self.h = rect.height() + 2 * self.margin
    self.w = rect.width() + 2 * self.margin
  end
  
  def margin
    self.settings.node[:margin]
  end
  
  def text_color
    self.settings.colors[:default_font]
  end
  
  def drawWidget(painter, x, y)
    xn = x + self.margin
    yn = y + self.margin
    painter.setPen self.text_color
    #painter.setBrush(Qt::Brush.new(self.settings.colors[:default_font])  )
    painter.setBrush Qt::NoBrush
    if self.top_level_widget.isActiveNode?(self)
      painter.drawRect xn, yn, xn + self.w, yn + self.h #DEBUG
    end
    painter.font = Qt::Font.new(font, painter.device())
    
    painter.drawText(
      Qt::PointF.new(xn, yn + self.h),
      self.text
    )
    
    x = x + self.w
    @slots.each do |slot|
      slot.drawWidget(painter, x, y)
      x = x + slot.w
    end
    
  end
  
  
  def passEvent(event)
    case event.key
      when Qt::Key_Backspace:
        self.setText(self.text[0..-2])
      when Qt::Key_Left
        handle_back
      when Qt::Key_Right
        handle_forward  
      else
        self.setText(self.text + event.text)
    end
  end
  
  private
  def handle_back
    if self.parent && self.parent.slot_pos >= 0
      if self.parent.slot_pos == 0
        self.top_level_widget.activeNode = self.parent
        self.parent.slot_pos = -1
      end
    end
  end
  
  def handle_forward
    if self.slots.present? && self.slot_pos == -1
      self.top_level_widget.activeNode = self.slots[0]
      self.slots[0].parent.slot_pos = 0
    end
  end
end

class ConstantNode < Node 
  def setText(text)
    super(text.camelize)
  end
  
  def text_color
    self.settings.colors[:constant]
  end
end

class IdentifierNode < Node  
  def setText(text)
    super(text.underscore)
  end
  
  def text_color
    self.settings.colors[:identifier]
  end
end

class ParamsNode < Node
  def setText(text)
    super("()")
  end
end





#CODE ------------------

class CodeWidget <  Qt::Widget
  def initialize(parent, settings) 
    super(parent)
    @parent = parent
    @settings = settings
    @child_nodes = []
    @active_node = nil
      
    NodeFactory.configure(self, @settings)
    cmp = NodeFactory.produce()
    cmp.setText("")
    @child_nodes << cmp
    
    @active_node = cmp
    
    setMinimumHeight PANEL_HEIGHT
    setFocusPolicy(Qt::StrongFocus)
  end
  
  def isActiveNode?(node)
    @active_node == node
  end
  
  def activeNode
    @active_node
  end
  
  def activeNode=(an)
    @active_node = an
  end
    
  def paintEvent event
    painter = Qt::Painter.new self
    #background
    if self.hasFocus()
      painter.setPen(Qt::Pen.new(@settings.colors[:focus]))
    else
      painter.setPen(Qt::NoPen)
    end
    painter.setBrush(Qt::Brush.new(@settings.colors[:background]))
    painter.drawRect(Qt::Rect.new(0,0, self.width - 1, self.height - 1))
    #components
    @child_nodes.each {|c| c.drawWidget(painter, 0, 0) }

    painter.end
  end
  
  def keyPressEvent(event)
    
    case event.key 
      #add a new element to the local @history
      when Qt::Key_Return:
        
      else
        self.activeNode.passEvent(event)  
        
    end
    self.repaint
    #super
  end
  
end

class QtApp < Qt::Widget 

    slots 'onChanged(int)'

    def initialize
        super
        setWindowTitle "Cothulhu"
        initUI

        resize 370, 200
        move 300, 300
        show
    end

    def initUI
    
       @cur_width = 0
       
       @slider = Qt::Slider.new Qt::Horizontal , self
       @slider.setMaximum MAX_CAPACITY
       @slider.setGeometry 50, 50, 130, 30 

       connect(@slider, SIGNAL("valueChanged(int)"), self, SLOT("onChanged(int)"))
       
       vbox = Qt::VBoxLayout.new self
       hbox = Qt::HBoxLayout.new

       vbox.addStretch 1

       @widget = CodeWidget.new(self, CodeWidgetSettings.new)

       hbox.addWidget @widget, 0

       vbox.addLayout hbox

       setLayout vbox
       @widget.setFocus()
    end

    def onChanged val
        @cur_width = val
        @widget.repaint
    end

    def getCurrentWidth
      return @cur_width
    end
end


app = Qt::Application.new ARGV
QtApp.new
app.exec
