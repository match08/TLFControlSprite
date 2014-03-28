package starling.extensions.events 
{
	
	import flashx.textLayout.events.CompositionCompleteEvent;
	import flashx.textLayout.events.StatusChangeEvent;
	
	import starling.events.Event;
	
	public class TLFFlowEvent extends starling.events.Event
	{
		public static const INLINE_GRAPHIC_STATUS_CHANGE  :String  = StatusChangeEvent.INLINE_GRAPHIC_STATUS_CHANGE;
		
		public static const COMPOSITION_COMPLETE			:String  = CompositionCompleteEvent.COMPOSITION_COMPLETE;
		
		public static const UPDATE							:String  = "textFlowUpdate";
		
		public static const COMPLETE						:String  = "textFlowComplete";
		
		public static const READY							:String  = "ready";
		
		public static const LINK_TOUCHED					:String  = "link_touched";
		
		public function TLFFlowEvent(type:String, bubbles:Boolean=false,data:Object=null)
		{
			super(type, bubbles, data);
		}
	}
}