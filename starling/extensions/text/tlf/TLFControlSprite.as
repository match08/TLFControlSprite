/**
 * 图文混排:在原作者基础上加入了<img/>标签支持,侦听，加入load xml和load html功能，支持feathers框架等
 * 			
 * Thank you for Guillaume Nachury
 * 
 * Version:beta2.1
 * 
 * Time：2014-05-16
 * 
 * DownLoad:https://github.com/match08
 * 
 * Based on source available on : http://wiki.starling-framework.org/extensions/tlfsprite
 * 
 * Simple modification of the tlfsprite in order to get the <a href="...">...</a> touchable
 * @author: Guillaume Nachury (guillaume.nachury@gmail.com)
 * 
 * dispatch a Starling event name 'link_touched' that contains le linked element touched as data
 * */

// =================================================================================================
//
//  based on starling.text.TextField
//  modified to use text layout framework engine for rendering text
//
// =================================================================================================

package starling.extensions.text.tlf {
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.text.engine.TextLine;
	
	import flashx.textLayout.compose.IFlowComposer;
	import flashx.textLayout.compose.TextFlowLine;
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.conversion.TextConverter;
	import flashx.textLayout.elements.FlowElement;
	import flashx.textLayout.elements.FlowGroupElement;
	import flashx.textLayout.elements.LinkElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.events.CompositionCompleteEvent;
	import flashx.textLayout.events.StatusChangeEvent;
	import flashx.textLayout.factory.TextFlowTextLineFactory;
	import flashx.textLayout.factory.TruncationOptions;
	import flashx.textLayout.formats.ITextLayoutFormat;
	import flashx.textLayout.formats.TextLayoutFormat;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.DisplayObjectContainer;
	import starling.display.Image;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import starling.extensions.display.LinkDisplay;
	import starling.extensions.events.TLFFlowEvent;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	
	import utils.StringUtil;
	
	 [Event(name="ready",type="starling.extensions.events.TLFFlowEvent")]
	 [Event(name="link_touched",type="starling.extensions.events.TLFFlowEvent")]
	 [Event(name="textFlowUpdate",type="starling.extensions.events.TLFFlowEvent")]
	 [Event(name="textFlowComplete",type="starling.extensions.events.TLFFlowEvent")]
	/** A TLFSprite displays text, using standard open type or true type fonts.
	 * 
	 * Rendering is done with a backing of the text layout framework engine as opposed
	 * to the classic flash.text.TextField as the standard starling.text.TextField employs.
	 * 
	 * If relying on embedded font use ensure TextLayoutFormat.fontLookup is set to FontLookup.EMBEDDED_CFF,
	 * this defaults to FontLookup.DEVICE, expecting device fonts.
	 * 
	 * Additionally, note that TLF expects embedded fonts with CFF, embedAsCFF="true" unlike
	 * classic TextField which uses embedded fonts with CFF disabled, embedAsCFF="false"
	 * 
	 * Download and find out more about the latest Text Layout Framework at
	 * <a href="http://sourceforge.net/adobe/tlf/home/Home/">Text Layout Framework</a>
	 */
	public class TLFControlSprite extends starling.display.Sprite
	{
		private static const XML_LAYOUT_ROOT:String='<TextFlow xmlns="http://ns.adobe.com/textLayout/2008"></TextFlow>';
		private static const XML_LAYOUT_REGEXP:RegExp = /<TextFlow.*? xmlns="http:\/\/ns.adobe.com\/textLayout\/2008".*?>.*?<\/TextFlow>/s;  
		
	
		private var mTextFlow:TextFlow;
		private var mFormat:TextLayoutFormat;
		
		private var mRequiresRedraw:Boolean;
		private var mType:String;
		private var mBorder:DisplayObjectContainer;
		
		private var mImage:Image;
		private var mSmoothing:String;
		
		private var mTruncationOptions:TruncationOptions;
		private var mCompositionBounds:Rectangle;
		
		// TLF rendering objects
		private static var sTextLineFactory:TextFlowTextLineFactory;
		private static var sTextLinesOrShapes:Vector.<flash.display.DisplayObject>;
		private static var sHelperMatrix:Matrix  = new Matrix();
		
		//Link management
		private var savedTLF:TextFlow;
		private var _linkMap:Array;
		private var linkClickEnable:Boolean = false;
		private var txtBounds:Rectangle;
		private static var _sTextLineFactory:TextFlowTextLineFactory;
		private var _savedTLF:TextFlow;
		
		
		private var _isFlatten:Boolean=false;
		
		private var _graphicIndex:int=0;
		private var _graphicLength:uint=0;
		
		protected var _showImaTag:Boolean=false;
		
		public var showBoundaries:Boolean = false;
		public var oversizeClickArea:Boolean = false;
		public var overSizeInPx:int = 10;
		
		
		/** Creates a TLFSprite from plain text. 
		 *  Optionally providing default formatting with TextLayoutFormat and composition
		 * width and height to limit active drawing area for rendering text 
		 * */
		public static function fromPlainText(text:String, format:TextLayoutFormat = null, 
											 compositionWidth:Number = 2048, compositionHeight:Number = 2048):TLFControlSprite
		{
			return fromFormat(text, TextConverter.PLAIN_TEXT_FORMAT, format, compositionWidth, compositionHeight);
		}
		
		/** Creates a TLFSprite from a string of HTML text, limited by the HTML tags the TLF engine supports.
		 *  See the Text Layout Framework documentation for supported tags.
		 * 
		 *  Optionally providing default formatting with TextLayoutFormat and composition
		 * width and height to limit active drawing area for rendering text 
		 * */
		public static function fromHTML(htmlString:String, format:TextLayoutFormat = null, 
										compositionWidth:Number = 2048, compositionHeight:Number = 2048,$isShowImaTag:Boolean=true):TLFControlSprite
		{
			return fromFormat(htmlString, TextConverter.TEXT_FIELD_HTML_FORMAT, format, compositionWidth, compositionHeight,$isShowImaTag);
		}
		
		/** Creates a TLFSprite from a string of text layout XML text, limited by the XML tags the TLF engine supports.
		 *  See the Text Layout Framework documentation for supported tags.
		 * 
		 *  Optionally providing default formatting with TextLayoutFormat and composition
		 * width and height to limit active drawing area for rendering text 
		 * */
		public static function fromTextLayout(layoutXMLString:String, format:TextLayoutFormat = null, 
											  compositionWidth:Number = 2048, compositionHeight:Number = 2048,$isShowImaTag:Boolean=true):TLFControlSprite
		{
			if(!XML_LAYOUT_REGEXP.test(layoutXMLString)){//防止空报错
				layoutXMLString = XML_LAYOUT_ROOT;
			}
			return fromFormat(layoutXMLString, TextConverter.TEXT_LAYOUT_FORMAT, format, compositionWidth, compositionHeight,$isShowImaTag);
		}
		
		
		
		private static function fromFormat(text:String, type:String, format:TextLayoutFormat = null, 
										   compositionWidth:Number = 2048, compositionHeight:Number = 2048,$isShowImaTag:Boolean=false):TLFControlSprite
		{
			var tlfSprite:TLFControlSprite = null;
			var textFlow:TextFlow = TextConverter.importToFlow(text ? text : "", type);
			
			
			if (textFlow)
				tlfSprite = new TLFControlSprite(textFlow, format, compositionWidth, compositionHeight, type,$isShowImaTag);
			
			return tlfSprite;
		}
		/*****************************************************************************
		 * 
		 * 加载外边xml和html解析布局
		 * 
		 * 
		 *****************************************************************************/
		/**
		 * 加载xml布局文件实例：
		 * <TextFlow  xmlns="http://ns.adobe.com/textLayout/2008">
		 * 	<p><img float="left" source="http://www.tang-studio.com/img/logo.png" width="244" height="62"/><span></span></p>
		 * </TextFlow>
		 * */
		
		public static function loadFromXMLTextLayout($url:String,$format:TextLayoutFormat = null, 
													 $compositionWidth:Number = 2048, $compositionHeight:Number = 2048):LoadLayout
		{
			LoadLayout.getInstance().loadXMLText($url,true,$format,$compositionWidth,$compositionHeight);
			return LoadLayout.getInstance();
		}
		/**
		 * <h1>加载html标签布局文件实例:</h1>
		 *<font size=5 color=0x360112><b>T-STUDIO[唐]</b></font>
		 * <br>换行标签<br>
		 * <p><a href='http//:www.tang-studio.com'>超链接标签：http//:www.tang-studio.com</a><p/>
		 *<img align="left" src ="http://www.tang-studio.com/img/logo.png" width="244" height="62"/>
		 * 
		 * */
		public static function loadFromHtmlTextLayout($url:String,$format:TextLayoutFormat = null, 
													  $compositionWidth:Number = 2048, $compositionHeight:Number = 2048,$isShowImgTag:Boolean=true):LoadLayout
		{
			LoadLayout.getInstance().loadXMLText($url,false,$format,$compositionWidth,$compositionHeight,$isShowImgTag);
			return LoadLayout.getInstance();
		}
		
		
		/**
		 * Basic constructor that takes an already constructed TLF TextFlow with optional
		 * default format and composition limits
		 * 
		 * See the static helper methods for quickly instantiating a TLFSprite from
		 * a simple plain text unformatted string, HTML or TLF text layout markup.
		 * */
		public function TLFControlSprite(textFlow:TextFlow, format:TextLayoutFormat = null, 
								  compositionWidth:Number = 2048, compositionHeight:Number = 2048, type:String="",$isShowImgTag:Boolean=true)
		{
			var links:Array = [];
			super();
			
			
			initTLF();
			
			mType = type;
			mTextFlow = textFlow;
		    _showImaTag = $isShowImgTag;
			//图像数
			if(_showImaTag)
				_graphicLength = textFlow.getElementsByTypeName('img').length;

				
			if(type == TextConverter.TEXT_FIELD_HTML_FORMAT){
				savedTLF = mTextFlow.deepCopy() as TextFlow;
				_savedTLF = mTextFlow.deepCopy() as TextFlow;
			}
			mTruncationOptions = new TruncationOptions();
			mCompositionBounds = new Rectangle( 0, 0, compositionWidth, compositionHeight);
			
			if (format) mFormat = format;
			else {
				mFormat = new TextLayoutFormat();
			}
			
			mSmoothing = TextureSmoothing.BILINEAR;
			addEventListener(starling.events.Event.FLATTEN, onFlatten);
			
			if(_showImaTag){
				//侦听事件:图形加载等------------------------------------------------------------------
				if(mTextFlow.hasEventListener(StatusChangeEvent.INLINE_GRAPHIC_STATUS_CHANGE))
					mTextFlow.removeEventListener(StatusChangeEvent.INLINE_GRAPHIC_STATUS_CHANGE, tlfEventHandler);
				mTextFlow.addEventListener(StatusChangeEvent.INLINE_GRAPHIC_STATUS_CHANGE, tlfEventHandler);
			}
			
			if(mTextFlow.hasEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE))
				mTextFlow.removeEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE, tlfEventHandler);
			mTextFlow.addEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE, tlfEventHandler);
			
			mRequiresRedraw = true;

		}

		
		/** Disposes the underlying texture data. */
		public override function dispose():void
		{
			removeEventListener(starling.events.Event.FLATTEN, onFlatten);
			mTextFlow.removeEventListener(StatusChangeEvent.INLINE_GRAPHIC_STATUS_CHANGE, tlfEventHandler);
			mTextFlow.removeEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE, tlfEventHandler);
			
			if (mImage) mImage.texture.dispose();
			removeLinkMap();
			super.dispose();
		}
		
		private function onFlatten(event:starling.events.Event=null):void
		{
			removeEventListener(starling.events.Event.FLATTEN, onFlatten);
			if (mRequiresRedraw) redrawContents();
		}
		
		protected function tlfEventHandler(event:flash.events.Event):void
		{
			if(event.type=="inlineGraphicStatusChange" && _showImaTag){

				if(mImage && _graphicIndex>0){
					if (mImage.texture) mImage.texture.dispose();//销毁上一次的纹理
					mImage.texture =Texture.fromBitmapData(createRenderedBitmapData());
				}
				if(_graphicLength == _graphicIndex ++){//加载完成
					_graphicIndex = 0;
					this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.COMPLETE));
				}
				this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.INLINE_GRAPHIC_STATUS_CHANGE));
				
			}else if(event.type=="compositionComplete"){
				this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.COMPOSITION_COMPLETE));
			}
			this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.UPDATE));
			
		}

		/** @inheritDoc */
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{

			if (mRequiresRedraw) redrawContents();
			super.render(support, parentAlpha);
		}
		
		private function redrawContents():void
		{
			createRenderedContents();
			mRequiresRedraw = false;
		}
		//创建并添加到显示对象
		private function createRenderedContents():void
		{
			var scale:Number  = Starling.contentScaleFactor;
			
			var bitmapData:BitmapData = createRenderedBitmapData();
			if (!bitmapData) return;
			
			var texture:Texture = Texture.fromBitmapData(bitmapData, false, false, scale);
			if (mImage == null) 
			{
				mImage = new Image(texture);
				mImage.touchable = false;
				mImage.smoothing = mSmoothing;
				addChild(mImage);
			}
			else 
			{ 
				if (mImage.texture) mImage.texture.dispose();
				mImage.texture = texture; 
				mImage.readjustSize(); 
			}
			updateBorder();
			
			this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.READY));
			
		}		
		/* **************************
		*  Event Handlers:
		****************************/
		private function onTxtTouch(e:TouchEvent):void
		{
			var txt:TLFControlSprite = e.currentTarget as TLFControlSprite;
			var touches:Vector.<Touch> = e.touches;
			if(touches[0].phase == TouchPhase.BEGAN){
				//使能超链接方式不使用外扩展方法，这里使用name获取实现
				//hitLinkDetection(touches[0].globalX-txt.x, touches[0].globalY-txt.y);
				if(e.target is LinkDisplay){
					dispatchEvent(new TLFFlowEvent(TLFFlowEvent.LINK_TOUCHED,true,(e.target as LinkDisplay).linkElem))
				}
			}
		}
		
		private function findBounds():void{
			var scale:Number  = Starling.contentScaleFactor;
			
			_sTextLineFactory.compositionBounds = mCompositionBounds;
			_sTextLineFactory.truncationOptions = mTruncationOptions;
			
			// NOTE: so that we function similar to Starling's TextField that hides
			// the fontSize scaling of Starling.contentScaleFactor internally,
			// we temporarily also scale up the format's fontSize setting only 
			// to then reset it when finished
			if (scale != 1.0) {
				var origFontSize:* = mFormat.fontSize;
				mFormat.fontSize = Math.max(1, Math.min(720, 
					(origFontSize == undefined ? 12 : origFontSize as Number)*scale));
			}
			
			savedTLF.hostFormat = mFormat;
			_sTextLineFactory.createTextLines( inop, _savedTLF);
			txtBounds = sTextLineFactory.getContentBounds();
		}
		
		private function inop(lineOrShape:flash.display.DisplayObject ):void{
			
		}
		
		/** 
		 * 渲染成位图数据
		 * 
		 * public in case one wants to use this class as a pipeline for
		 * creating bitmap data outside the typical end use of a sprite's texture
		 * */
		public function createRenderedBitmapData():BitmapData 
		{
			if (!mTextFlow) return null;
			
			var scale:Number  = Starling.contentScaleFactor;
			
			// clear out any existing text lines or shapes
			sTextLinesOrShapes.length = 0;
			
			sTextLineFactory.compositionBounds = mCompositionBounds;
			sTextLineFactory.truncationOptions = mTruncationOptions;
			
			// NOTE: so that we function similar to Starling's TextField that hides
			// the fontSize scaling of Starling.contentScaleFactor internally,
			// we temporarily also scale up the format's fontSize setting only 
			// to then reset it when finished
			if (scale != 1.0) {
				var origFontSize:* = mFormat.fontSize;
				mFormat.fontSize = Math.max(1, Math.min(720, 
					(origFontSize == undefined ? 12 : origFontSize as Number)*scale));
			}
			
			mTextFlow.hostFormat = mFormat;
			sTextLineFactory.createTextLines( generatedTextLineOrShape, mTextFlow);
			
			// after lines are generated we can ask the factory for the content
			// bounds that encompasses the current line renderings
			var contentBounds:Rectangle = sTextLineFactory.getContentBounds();
			
			// Reset modified fontSize value
			if (scale != 1.0) mFormat.fontSize = origFontSize;
			
			var textWidth:Number  = Math.min(2048, contentBounds.width*scale);
			var textHeight:Number = Math.min(2048, contentBounds.height*scale);
			
			textWidth = textWidth ==0 ?compositionWidth: textWidth;
			textHeight = textHeight ==0 ?compositionHeight: textHeight;
			
			
			var bitmapData:BitmapData = new BitmapData(textWidth, textHeight, true, 0x0);
			
			// draw each text line or shape into bitmap
			var lineOrShape:flash.display.DisplayObject;
			for (var i:int = 0; i < sTextLinesOrShapes.length; ++i) {
				lineOrShape = sTextLinesOrShapes[i];
				sHelperMatrix.setTo(scale, 0, 0, scale, 
					(lineOrShape.x - contentBounds.x)*scale, (lineOrShape.y - contentBounds.y)*scale);
				bitmapData.draw(lineOrShape, sHelperMatrix);
				
			}
			//let's create a map of all the clickable areas
			if(mType == TextConverter.TEXT_FIELD_HTML_FORMAT){
			
				createLinkMap(textWidth, textHeight);
			}
			
			// finished need for generated lines or shapes
			sTextLinesOrShapes.length = 0;
			
			return bitmapData;
		}
		/**渲染为bitmap*/
		public function createRenderedBitmap():Bitmap{
			return new Bitmap(createRenderedBitmapData());
		}
		/**渲染为Texture*/
		public function createRenderedTexture():Texture{
			return Texture.fromBitmapData(createRenderedBitmapData());
		}
		/**渲染为Image*/
		public function createRenderedImage():Image{
			return new Image(Texture.fromBitmapData(createRenderedBitmapData()));
		}
		
		//创建超链接************************************************************************
		private function createLinkMap(textW:Number, textH:Number):void{
			
			var ctrlr:ContainerController = new ContainerController(new flash.display.Sprite(), textW,textH);	
			savedTLF.flowComposer.addController(ctrlr);
			savedTLF.flowComposer.updateAllControllers();
			
			var composer:IFlowComposer = savedTLF.flowComposer;
			composer.compose();
			var links:Array = [];
			
			links = savedTLF.getElementsByTypeName("a");	
			_linkMap = new Array();
			
			for each (var le:LinkElement in links){	

				_linkMap=_linkMap.concat(createClickableZone(le, composer));
			}
			
			removeLinkMap();
			
			//超链点击,用linkDisPlay实现
			for (var i:int = 0; i < _linkMap.length; i++) 
			{
				var linkObject:Object = _linkMap[i];
				var rec:Rectangle = linkObject.area as Rectangle;
				var linkDisPlay:LinkDisplay = new LinkDisplay(rec.width, rec.height, 0xaa0000);
				linkDisPlay.x = rec.x;
				linkDisPlay.y = rec.y;
				linkDisPlay.alpha = showBoundaries?0.3:0;
				
				
				linkDisPlay.linkElem=linkObject.linkElem;
			
				addChild(linkDisPlay);
				
			}
			
		}
		//移除超链接************************************************************************
		private function removeLinkMap():void{
			
			while(numChildren>1){
				var obj:* = getChildAt(0);
				removeChild(obj);
				if(obj is LinkDisplay){
					obj.dispose();
				}
			}
		}
		
		private function createClickableZone(le:LinkElement, composer:IFlowComposer):Array{
			var area:Array = [];
			var absStart:int = le.getAbsoluteStart();
			var textFlowLine:TextFlowLine= composer.findLineAtPosition(absStart);
			var textLine:TextLine = textFlowLine.getTextLine(true);
			
			var lineLength:int = textFlowLine.textLength;
			var rectBoundary:Rectangle = textLine.getAtomBounds(textLine.getAtomIndexAtCharIndex(le.parentRelativeStart));
			rectBoundary.y = textFlowLine.y;
			if(oversizeClickArea){
				rectBoundary.y -= overSizeInPx;
				rectBoundary.height +=(overSizeInPx*2);
				rectBoundary.x -=overSizeInPx;
			}
			
			var linkLength:int = le.getText().length;
			
			var ptr:int = textLine.getAtomIndexAtCharIndex(le.parentRelativeStart);
			ptr++;
			absStart++;
			for (var i:int = 1; i < linkLength; i++) //start a idx=1 because we already got the 1st bound
			{
				if(ptr>lineLength){
					if(oversizeClickArea){
						rectBoundary.width +=(overSizeInPx*2);
					}
					area.push({linkElem:le,area:rectBoundary});
					textFlowLine = composer.findLineAtPosition(absStart);
					lineLength = textFlowLine.textLength;
					ptr=0;
					rectBoundary = textLine.getAtomBounds(ptr);
				}
				else{
					var newCharBounds:Rectangle = textLine.getAtomBounds(ptr);
					rectBoundary = new Rectangle(rectBoundary.x, rectBoundary.y, rectBoundary.width+newCharBounds.width, rectBoundary.height);
				}
				ptr++;
				absStart++;
			}
			if(oversizeClickArea){
				rectBoundary.width +=(overSizeInPx*2);
			}
			area.push({linkElem:le,area:rectBoundary});
			
			
			return area;
		}		
		/**
		 * 超链接外部调用扩展方法:
		 * 方法01：
		 * private function onTxtTouch(te:TouchEvent):void
		 *	{
		 *		var tlf:TLFControlSprite = te.currentTarget as TLFControlSprite;
		 * 		var touches:Vector.<Touch> = te.touches;
		 * 		if(touches[0].phase == TouchPhase.BEGAN){
		 *			tlf.hitLinkDetection(touches[0].globalX-txt.x,touches[0].globalY-txt.y);
		 *		}
		 *	}
		 * 方法01：结合组件方法(例如：ScrollContainer)
		 * private function onTxtTouch(te:TouchEvent):void
		 *	{
		 *		var tlf:TLFControlSprite = te.currentTarget as TLFControlSprite;
		 * 		var touches:Vector.<Touch> = te.touches;
		 * 		if(touches[0].phase == TouchPhase.BEGAN){
		 *			tlf.hitLinkDetection(touches[0].globalX-sc.x+sc.horizontalScrollPosition,touches[0].globalY-sc.y+sc.verticalScrollPosition);
		 *		}
		 *	}
		 * */
		public function hitLinkDetection(touchX:Number, touchY:Number):void{
			
			for each (var o:Object in _linkMap) 
			{
				var rect:Rectangle = o.area;
				if(rect.contains(touchX, touchY)){
					this.dispatchEvent(new TLFFlowEvent(TLFFlowEvent.LINK_TOUCHED,true, o.linkElem));
					return;
				}
			}
			
		}

		//显示	
		private function displayBoundaries(rect:Rectangle):void{
			var quad:Quad = new Quad(rect.width, rect.height, 0xaa56321);
			quad.x = rect.top;
			quad.y = rect.left;
			addChild(quad);
		}
		
		private function findLinkElement(group:FlowGroupElement, arr:Array):Array {
			var childGroups:Array = [];
			for (var i:int = 0; i < group.numChildren; i++) {
				var element:FlowElement = group.getChildAt(i);
				if (element is LinkElement) {
					arr.push(element as LinkElement);
				} else if (element is FlowGroupElement) {
					childGroups.push(element);
				}
			}
			for (i = 0; i < childGroups.length; i++) {
				var childGroup:FlowGroupElement = childGroups[i];
				findLinkElement(childGroup, arr);				
			}
			return arr;
		}
		//初始化
		private static function initTLF():void
		{
			if (sTextLineFactory == null) {	
				sTextLineFactory = new TextFlowTextLineFactory();
				_sTextLineFactory = new TextFlowTextLineFactory();
				sTextLinesOrShapes = new <flash.display.DisplayObject>[];
			}
	
		}
		
		/** generated TextLines or Shapes (from background colors etc..)
		 *  get added to a collected vector of results
		 * */
		private function generatedTextLineOrShape( lineOrShape:flash.display.DisplayObject ):void
		{
			sTextLinesOrShapes.push(lineOrShape);
		}
		
		private function updateBorder():void
		{
			if (mBorder == null || mImage == null) return;
			
			var width:Number  = mImage.width;
			var height:Number = mImage.height;
			
			var topLine:Quad    = mBorder.getChildAt(0) as Quad;
			var rightLine:Quad  = mBorder.getChildAt(1) as Quad;
			var bottomLine:Quad = mBorder.getChildAt(2) as Quad;
			var leftLine:Quad   = mBorder.getChildAt(3) as Quad;
			
			topLine.width    = width; topLine.height    = 1;
			bottomLine.width = width; bottomLine.height = 1;
			leftLine.width   = 1;     leftLine.height   = height;
			rightLine.width  = 1;     rightLine.height  = height;
			rightLine.x  = width  - 1;
			bottomLine.y = height - 1;
			topLine.color = rightLine.color = bottomLine.color = leftLine.color = mFormat.color;
		}
		
		/** @inheritDoc */
		public override function getBounds(targetSpace:starling.display.DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if(mImage){
				return mImage.getBounds(targetSpace, resultRect);
			}
			else{
				return txtBounds;
			}
			
		}
		
		/** Calling set text makes the assumption that you now expect only
		 *  simple content with external formats and completely replace any
		 * previously set content, plain text, html or otherwise
		 * */
		public function set text(value:String):void
		{
			mTextFlow = TextConverter.importToFlow(value ? value : "", TextConverter.PLAIN_TEXT_FORMAT);
			mRequiresRedraw = true;
		}
		
		/** Calling set html makes the assumption that you now expect
		 *  HTML content and completely replace any
		 * previously set content, plain text, html or otherwise
		 * */
		public function set html(value:String):void
		{
			mTextFlow = TextConverter.importToFlow(value ? value : "", TextConverter.TEXT_FIELD_HTML_FORMAT);
			mRequiresRedraw = true;
		}
		
		/** Calling set textLayout makes the assumption that you now expect
		 *  Text layout markup content and completely replace any
		 * previously set content, plain text, html or otherwise
		 * */
		public function set textLayout(value:String):void
		{
			mTextFlow = TextConverter.importToFlow(value ? value : "", TextConverter.TEXT_LAYOUT_FORMAT);
			mRequiresRedraw = true;
		}
		
		public function get compositionWidth():Number {return mCompositionBounds.width;}
		public function set compositionWidth(value:Number):void
		{
			if (value != mCompositionBounds.width) {
				mCompositionBounds.width = value;
				mRequiresRedraw = true;
			}
		}
		
		public function get compositionHeight():Number {return mCompositionBounds.height;}
		public function set compositionHeight(value:Number):void
		{
			if (value != mCompositionBounds.height) {
				mCompositionBounds.height = value;
				mRequiresRedraw = true;
			}
		}
		
		public function get truncationOptions():TruncationOptions {return mTruncationOptions;}
		public function set truncationOptions(value:TruncationOptions):void 
		{
			mTruncationOptions = value;
			mRequiresRedraw = true;
		}
		
		/** Draws a border around the edges of the text field. Useful for visual debugging. 
		 *  @default false */
		public function get border():Boolean { return mBorder != null; }
		public function set border(value:Boolean):void
		{
			if (value && mBorder == null)
			{                
				mBorder = new starling.display.Sprite();
				addChild(mBorder);
				
				for (var i:int=0; i<4; ++i)
					mBorder.addChild(new Quad(1.0, 1.0));
				
				updateBorder();
			}
			else if (!value && mBorder != null)
			{
				mBorder.removeFromParent(true);
				mBorder = null;
			}
		}
		
		/** The smoothing filter that is used for the image texture. 
		 *   @default bilinear
		 *   @see starling.textures.TextureSmoothing */ 
		public function get smoothing():String { return mSmoothing; }
		public function set smoothing(value:String):void 
		{
			if (TextureSmoothing.isValid(value)) {
				mSmoothing = value;
				if (mImage) mImage.smoothing = mSmoothing;
			}
			else
				throw new ArgumentError("Invalid smoothing mode: " + value);
		}
		
		/** Returns the value of the style specified by the <code>styleProp</code> parameter, which specifies
		 * the style name from the text's TextLayoutFormat.
		 *
		 * @param styleProp The name of the style whose value is to be retrieved.
		 *
		 * @return The value of the specified style. The type varies depending on the type of the style being
		 * accessed. Returns <code>undefined</code> if the style is not set.
		 */
		public function getStyle(styleProp:String):*
		{
			return mFormat.getStyle(styleProp);
		}
		
		/** Sets the style specified by the <code>styleProp</code> parameter to the value specified by the
		 * <code>newValue</code> parameter. 
		 *
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param styleProp The name of the style to set.
		 * @param newValue The value to which to set the style.
		 */
		public function setStyle(styleProp:String,newValue:*):void
		{
			mFormat.setStyle(styleProp, newValue);
			mRequiresRedraw = true;
		}
		
		/** Returns the styles on this text's TextLayoutFormat.  Note that the getter makes a copy of the  
		 * styles dictionary. The coreStyles object encapsulates all styles set in the format property including core and user styles. The
		 * returned object consists of an array of <em>stylename-value</em> pairs.
		 * 
		 * @see flashx.textLayout.formats.TextLayoutFormat
		 */
		public function get styles():Object
		{
			return mFormat.styles;
		}
		
		/**
		 * Replaces property values in this text's TextLayoutFormat object with the values of properties that are set in
		 * the <code>incoming</code> ITextLayoutFormat instance. Properties that are <code>undefined</code> in the <code>incoming</code>
		 * ITextLayoutFormat instance are not changed in this object.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param incoming instance whose property values are applied to this text's TextLayoutFormat object.
		 */
		public function apply(incoming:ITextLayoutFormat):void
		{
			mFormat.apply(incoming);
			mRequiresRedraw = true;
		}
		
		/**
		 * Concatenates the values of properties in the <code>incoming</code> ITextLayoutFormat instance
		 * with the values of this text's TextLayoutFormat object. In this (the receiving) TextLayoutFormat object, properties whose values are <code>FormatValue.INHERIT</code>,
		 * and inheriting properties whose values are <code>undefined</code> will get new values from the <code>incoming</code> object.
		 * Non-inheriting properties whose values are <code>undefined</code> will get their default values.
		 * All other property values will remain unmodified.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param incoming instance from which values are concatenated.
		 */
		public function concat(incoming:ITextLayoutFormat):void
		{
			mFormat.concat(incoming);
			mRequiresRedraw = true;
		}
		
		/**
		 * Concatenates the values of properties in the <code>incoming</code> ITextLayoutFormat instance
		 * with the values of this text's TextLayoutFormat object. In this (the receiving) TextLayoutFormat object, properties whose values are <code>FormatValue.INHERIT</code>,
		 * and inheriting properties whose values are <code>undefined</code> will get new values from the <code>incoming</code> object.
		 * All other property values will remain unmodified.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param incoming instance from which values are concatenated.
		 */
		public function concatInheritOnly(incoming:ITextLayoutFormat):void
		{
			mFormat.concatInheritOnly(incoming);
			mRequiresRedraw = true;
		}
		
		/**
		 * Copies TextLayoutFormat settings from the <code>values</code> ITextLayoutFormat instance into this text's TextLayoutFormat object.
		 * If <code>values</code> is <code>null</code>, this TextLayoutFormat object is initialized with undefined values for all properties.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param values optional instance from which to copy values.
		 */
		public function copy(incoming:ITextLayoutFormat):void
		{
			mFormat.copy(incoming);
			mRequiresRedraw = true;
		}
		
		/**
		 * Sets properties in this text's TextLayoutFormat object to <code>undefined</code> if they do not match those in the
		 * <code>incoming</code> ITextLayoutFormat instance.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param incoming instance against which to compare this TextLayoutFormat object's property values.
		 */
		public function removeClashing(incoming:ITextLayoutFormat):void
		{
			mFormat.removeClashing(incoming);
			mRequiresRedraw = true;
		}
		
		/**
		 * Sets properties in this text's TextLayoutFormat object to <code>undefined</code> if they match those in the <code>incoming</code>
		 * ITextLayoutFormat instance.
		 * 
		 * Contents are redrawn with the updated property changes on the next render.
		 * 
		 * @param incoming instance against which to compare this TextLayoutFormat object's property values.
		 */
		public function removeMatching(incoming:ITextLayoutFormat):void
		{
			mFormat.removeMatching(incoming);
			mRequiresRedraw = true;
		}

		
		//重写方法*************************************************************************************************************************
		

		/**
		 * 添加侦听
		 */
		override public function addEventListener($type:String, $listener:Function):void{
			
			super.addEventListener($type, $listener);
			
			if($type==TLFFlowEvent.LINK_TOUCHED){//超链接
				
				if(!hasEventListener(TouchEvent.TOUCH)){
					linkClickEnable=true;
					addEventListener(TouchEvent.TOUCH, onTxtTouch);
				}
			}		
			//全部加载完成/更新
			if($type==TLFFlowEvent.COMPLETE ||$type==TLFFlowEvent.UPDATE ||$type==TLFFlowEvent.READY){
				onFlatten();
			}
			
		}

		//************************************************************************************************************************************
		/**
		 * 使用类型查找元素集:
		 * getElementsByTypeName('p');
		 * @param  $typeNameValue  'img'  'p'  'a' ...
		 * @return Array
		 * */
		public function getElementsByTypeName($typeNameValue:String):Array{
			return mTextFlow.getElementsByTypeName($typeNameValue);
		}
		/**
		 * 使用id查找元素
		 * <img id='myImg'/>   getElementsByID('myImg');  
		 * @param    $idName   elements's id 
		 * @return   FlowElement
		 * */
		public function getElementsByID($idName:String):FlowElement{
			return mTextFlow.getElementByID($idName);
		}

	
	}
}

import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.net.URLLoader;
import flash.net.URLRequest;

import flashx.textLayout.elements.LinkElement;
import flashx.textLayout.formats.TextLayoutFormat;

import starling.extensions.events.TLFFlowEvent;
import starling.extensions.text.tlf.TLFControlSprite;


class LoadLayout{
		
	private static var _loadLayout:LoadLayout;
	private static var _dicTemp:Array;

	//指针-------------------------------------------------
	private function getDicTempLink($url:String):String {
		return $url+"__link";
	}
	private function getDicTempUpdateFun($url:String):String {
		return $url+"__updateFun";
	}
	private function getDicTempOnCompleteFun($url:String):String {
		return $url+"__onCompleteFun";
	}
	private function getDicTempLayoutType($url:String):String {
		return $url+"__isXML";
	}
	private function getDicTempLinkFun($url:String):String {
		return $url+"__LinkFun";
	}

	private var _url:String;

	/**设置加载类型:xml或html*/
	public function layoutType($isXml:Boolean=false):LoadLayout{
		_dicTemp[getDicTempLayoutType(_url)] =$isXml;
		return _loadLayout;
	}
	/**
	 * 入口：实例化方法
	 * */
	public static function getInstance():LoadLayout{
		if(_loadLayout ==null){
			_loadLayout = new LoadLayout();
		}
		return _loadLayout;
	}
	/**
	 * 加载时返回
	 * */
	public function update($vulae:Function):LoadLayout{
		if($vulae)
			_dicTemp[getDicTempUpdateFun(_url)]= $vulae;
		return _loadLayout;
	}
	/**
	 * 加载完成返回
	 * */
	public function onComplete($vulae:Function):LoadLayout{
		if($vulae)
			_dicTemp[getDicTempOnCompleteFun(_url)]= $vulae;
		return _loadLayout;
	}
	/**
	 * 超链接返回
	 * */
	public function  onLinkTouched($linElementFun:Function):LoadLayout{
		_dicTemp[getDicTempLinkFun(_url)]=$linElementFun;
		return _loadLayout;
	}
	//private static var _isXML:Boolean = true;
	private static var _XMLloader:URLLoader;
	private static var _tempLoadXmlText:Vector.<String>;
	//加载外部文件
	internal function loadXMLText($url:String,$isXML:Boolean=true,$format:TextLayoutFormat = null,$compositionWidth:Number = 2048, $compositionHeight:Number = 2048,$isShowImgTag:Boolean=true):LoadLayout{
		
		_url = $url;
		if(_tempLoadXmlText==null){
			_tempLoadXmlText = new Vector.<String>();
			_dicTemp = new Array();
		}
		layoutType($isXML);//设置layout类型
		_tempLoadXmlText.push($url);
		
		if(_XMLloader==null){
			
			var shiftUrl:String = _tempLoadXmlText.shift();
			
			_XMLloader = new URLLoader();
			_XMLloader.addEventListener(Event.COMPLETE, loadComplete);
			_XMLloader.addEventListener(IOErrorEvent.IO_ERROR, loadError);
			_XMLloader.load(new URLRequest(shiftUrl));
		}
		

		function loadComplete(e:flash.events.Event):void {

			var updateFun:Function =  _dicTemp[getDicTempUpdateFun(shiftUrl)];
			var onComPleteFun:Function =  _dicTemp[getDicTempOnCompleteFun(shiftUrl)];

			var text:String = String(_XMLloader.data);
			var tlfFlow:TLFControlSprite;
		
			var isXMLType:Boolean = _dicTemp[getDicTempLayoutType(shiftUrl)];
			var linkClickFun:Function = _dicTemp[getDicTempLinkFun(shiftUrl)];

			if(isXMLType){
				
					tlfFlow = TLFControlSprite.fromTextLayout(text,$format,$compositionWidth,$compositionHeight,$isShowImgTag);

			}else{
					
					tlfFlow = TLFControlSprite.fromHTML(text,$format,$compositionWidth,$compositionHeight,$isShowImgTag);
			}
				
			if(linkClickFun){//超链接使能返回
				tlfFlow.addEventListener(TLFFlowEvent.LINK_TOUCHED,linkClickFun);
			}
			tlfFlow.createRenderedBitmapData();
			
			if(updateFun!=null)
				updateFun(tlfFlow);
			
			if(onComPleteFun!=null)
				tlfFlow.addEventListener(TLFFlowEvent.COMPLETE,onComplete);
			

			function onComplete(e:TLFFlowEvent):void{
				tlfFlow.removeEventListener(TLFFlowEvent.COMPLETE,onComplete);
				onComPleteFun(tlfFlow);
			}
			
			if(_tempLoadXmlText.length>0){
				shiftUrl = _tempLoadXmlText.shift();
				_XMLloader.load(new URLRequest(shiftUrl));
			}else{//全部加载完成后卸载和释放
				_XMLloader.removeEventListener(flash.events.Event.COMPLETE, loadComplete);
				_XMLloader.removeEventListener(flash.events.IOErrorEvent.IO_ERROR, loadError);
				_XMLloader =null;
				_tempLoadXmlText = null;
				_dicTemp=null;
			}
			
		}
		
		function loadError(e:IOErrorEvent):void {
			throw(new Error("TLFText加载XML文本错误！！！"));
		}
		
		return _loadLayout;
	}
	
	

}


