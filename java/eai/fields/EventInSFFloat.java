//GENERATED BY genfields.pl. DO NOT EDIT!
package vrml.external.field;
import vrml.external.*;
import java.util.*;

public class EventInSFFloat extends EventIn {
		FreeWRLBrowser browser;
		String nodeid;
		String id;
		public EventInSFFloat(FreeWRLBrowser b, String n, String i) {
			browser = b;
			nodeid = n;
			id = i;
			System.out.println("New SFFloat: "+n+" "+id);
		}
		public void setValue(float val) 
			 {
				float v;
;
				;
				v=val;
				browser.send__eventin(nodeid,id, new Float(v).toString()) ;
		}
	}
	