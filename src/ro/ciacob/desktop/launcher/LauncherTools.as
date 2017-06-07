package ro.ciacob.desktop.launcher {
	import ro.ciacob.desktop.data.IDataElement;
	import ro.ciacob.desktop.launcher.constants.KnownScripts;
	import ro.ciacob.utils.Files;
	import ro.ciacob.utils.Strings;
	import ro.ciacob.utils.constants.CommonStrings;
	import ro.ciacob.utils.constants.GenericFieldNames;

	public final class LauncherTools {
		
		
		public static const EMPTY_SUITE : String = 'found empty suite';
		public static const HAS_SEPARATOR : String = 'found separator item';
		public static const HAS_UNLAUNCHABLE_ITEM : String = 'found unlaunchable item';
		public static const HAS_GROUP_ITEM : String = 'found group item';
		
		public static function isLaunchable (item : IDataElement) : Boolean {
			
			var path : String = Strings.trim (item.getContent(GenericFieldNames.PATH));
			var hasValidPath : Boolean = Files.isValidPath (path);
			var details : String = item.getContent(GenericFieldNames.CONFIGURATION);
			var hasBatch : Boolean = Strings.contains(details, KnownScripts.BATCH_HEADER);
			var hasWjs : Boolean = Strings.contains(details, KnownScripts.WJS_HEADER);
			return (isSuite(item) || isWebLink(item) || hasValidPath || hasBatch || hasWjs);
		}
		
		public static function isSeparator (item : IDataElement) : Boolean {
			return (item.getContent(GenericFieldNames.TYPE) == GenericFieldNames.SEPARATOR);
		}
		
		public static function isSuite (item : IDataElement) : Boolean {
			return (item.getContent(GenericFieldNames.TYPE) == GenericFieldNames.SUITE);
		}

		public static function isGroup (item : IDataElement) : Boolean {
			return (item.getContent(GenericFieldNames.TYPE) == GenericFieldNames.ITEM && 
				item.numDataChildren > 0);
		}
		
		public static function labelOf (item : IDataElement) : String {
			return Strings.trim (Strings.stripTags(item.getContent(GenericFieldNames.LABEL)));
		}
		
		private static function _compileErrorFor (error : String, detail : String) : String {
			if (detail) {
				error = [error, CommonStrings.SPACE, Strings.quote(detail)].join(CommonStrings.EMPTY);
			}
			return error;
		}
		
		/**
		 * Proofs that given suite node only contains "launchable" items, i.e., items with either valid paths or
		 * (presumably valid) script content, or other cascaded suite(s), validated by the same rules.
		 * 
		 * Returns `null` when validation fails, or a Vector of IDataElements containing a flatten out 
		 * representation of the suite, on success.
		 * 
		 * @param suite An element to be validated as a suite
		 * 
		 * @param errorReporter A closure to be passed details about a suite that fails validation. 
		 * Must take one argument of type string.
		 */
		public static function sanitizeSuiteContent(suite:IDataElement, errorReporter : Function = null):Vector.<IDataElement> {
			
			var offendingItemLabel : String = null;
			var error : String = null;
			
			// Fail: suites mustn't be empty
			if (suite.numDataChildren == 0) {
				if (errorReporter != null) {
					errorReporter (EMPTY_SUITE);
				}
				return null;
			}
			
			var data:Vector.<IDataElement> = new Vector.<IDataElement>;
			for (var i:int = 0; i < suite.numDataChildren; i++) {
				var dataChild:IDataElement = suite.getDataChildAt(i);
				
				// Fail: there is at least one separator in this suite
				if (LauncherTools.isSeparator(dataChild)) {
					if (errorReporter != null) {
						errorReporter (HAS_SEPARATOR);
					}
					return null;
				}
				
				// Fail: there is at least one unlaunchable item in this suite
				if (!LauncherTools.isLaunchable (dataChild)) {
					if (errorReporter != null) {
						errorReporter (_compileErrorFor(HAS_UNLAUNCHABLE_ITEM, labelOf (dataChild)));
					}
					return null;
				}
				
				var isSuite : Boolean = LauncherTools.isSuite (dataChild);
				var hasChildren : Boolean = (dataChild.numDataChildren > 0);
				
				// Fail: there is at least one group item in this suite
				if (hasChildren && !isSuite) {
					if (errorReporter != null) {
						errorReporter (_compileErrorFor(HAS_GROUP_ITEM, labelOf (dataChild)));
					}
					return null;
				}
				
				// Recurse into any child suites we might have
				if (isSuite) {
					var result : Vector.<IDataElement> = sanitizeSuiteContent (dataChild, errorReporter);
					if (result != null) {
						data = data.concat (result);
						continue;
					} 
						
					// Fail: there is at least one item in a (gran)child suite that is
					// either a separator, or a group, or it is unlaunchable.
					else {
						return null;
					} 
				}
				
				// If we reached down here, then our current item passed. We add it to
				// our collection
				data.push (dataChild);
			}
			return data;
		}
		
		public static function isWebLink(item:IDataElement):Boolean {
			var path:String = item.getContent(GenericFieldNames.PATH);
			if (path != null) {
				return ( Strings.beginsWith (path, 'http://') || Strings.beginsWith (path, 'https://') );
			}
			return false;
		}
	}
}