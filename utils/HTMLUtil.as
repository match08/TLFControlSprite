package utils
{
	
	/** 
	 * @author 
	 *
	 * @web:	
	 *
	 * @version 0.1.0 
	 *
	 * 创建时间：2014-5-16 下午1:32:04 
	 * */
	
	
	public class HTMLUtil
	{
		/**
		 * 将html文本样式标签替换为htmlText可识别的标签
		 * @author Non
		 * @param html 原html文本
		 * @param imgScale 对图片的缩放倍数
		 * @param $isReplaceClass  移除标签中的class
		 * @return 替换后的html标签字符串
		 */	
		public static function convertUselessTag($html:String,$isReplaceClass:Boolean = true, $imgScale:Number = 1):String
		{
			$html = $html.replace(/\r\n/g, ' '); // 去除 \r\n (windows)
			$html = $html.replace(/\n/g, ' '); // 去除 \n (linux)
			$html = $html.replace(/<\s*\/?(div)(\s[^>]*)?>/g, ''); //去除 div标签
			
			if($isReplaceClass){
				// 去除标签中的 class属性
				var classes:Array = $html.match(/<\s*(\S+)\s+([^\s>]*\s*class=[^\s>]*)/g);
				for each (var classTag:String in classes)
				{
					classTag = classTag.replace(/\s+class=[^\s>]*/, ''); 
					$html = $html.replace(/<\s*(\S+)\s+([^\s>]*\s*class=[^\s>]*)/, classTag);
				}
			}
			
			var lastChar:String;
			
			// 缩放img
			if ($imgScale != 1)
			{
				var imgs:Array = $html.match(/<img\s+[^>]*[(width)|(height)]=[^>]+>/g);
				for each (var imgTag:String in imgs)
				{
					// 给宽高值乘缩放系数
					var ws:Array = imgTag.match(/\s+width=['"]?[^\s\/>]+['"]?[\s\/>]/);
					if (ws != null && ws.length > 0)
					{
						var w:String = ws[0];
						w = w.split("=")[1];
						lastChar = w.charAt(w.length - 1);
						w = w.substr(0, w.length - 1);
						w = w.replace(/['"]/g, '');
						w = (parseInt(w) * $imgScale).toString();
						
						imgTag = imgTag.replace(/\s+width=['"]?[^\s\/>]+['"]?[\s\/>]/, ' width=' + w + lastChar);
					}
					
					var hs:Array = imgTag.match(/\s+height=['"]?[^\s\/>]+['"]?[\s\/>]/);
					if (hs != null && hs.length > 0)
					{
						var h:String = hs[0];
						h = h.split("=")[1];
						lastChar = h.charAt(h.length - 1);
						h = h.substr(0, h.length - 1);
						h = h.replace(/['"]/g, '');
						h = (parseInt(h) * $imgScale).toString();
						
						imgTag = imgTag.replace(/\s+height=['"]?[^\s\/>]+['"]?[\s\/>]/, ' height=' + h + lastChar);
					}
					
					$html = $html.replace(/<img\s+[^>]*[(width)|(height)]=[^>]+>/, imgTag);
				}
			}
			
			// 替换span为font
			var spans:Array = $html.match(/<span\s+[^>]*style=[^>]+>/g);
			for each (var span:String in spans)
			{
				span = span.replace(/\s+lang=[^\s>]*/g, ''); // 去除 lang属性
				
				var styles:Array = span.match(/\s+style=['"][^>]+['"][\s>]/);
				if (styles == null || styles.length == 0) continue;
				var style:String = styles[0];
				lastChar = style.charAt(style.length - 1);
				style = style.substr(0, style.length - 2);// 去除最后俩字符['"][\s>]，即返回后引号之前的字符
				
				// 给字体属性font-family值加引号
				var tmp:Array = style.match(/font-family:[^;]+/);
				if (tmp != null && tmp.length > 0)
				{
					var s:String = tmp[0];
					s = s.split(",")[0];
					if (s.indexOf("\"") == -1 && s.indexOf("\'") == -1)
					{
						s = "font-family:\"" + s.substring(12) + "\"";
					}
					style = style.replace(/font-family:[^;]+/, s);
				}
				// span style属性替换为font相关属性
				style = style.replace(/\s+style=['"]/, '');
				style = style.replace(/;? *font-family:/, ' face=');
				style = style.replace(/;? *font-size:/, ' size=');
				style = style.replace(/;? *color:/, ' color=');
				
				span = span.replace(/\s+style=['"][^>]+['"][\s>]/, style + lastChar);
				$html = $html.replace(/<span\s+[^>]*style=[^>]+>/, span);
			}
			$html = $html.replace(/<span/g, '<font');
			$html = $html.replace(/<\/span>/g, '<\/font>');
			
			return StringUtil.trim($html);
		}
		
		
	}
}