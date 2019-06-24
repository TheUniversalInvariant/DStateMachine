module mDStateMachine;

//version = EnableGraphing;
// Set Paths to apngasm.exe and apngViewer such as ifranview.
enum APNGBin = ``;
enum APNGViewer = ``;



// Gets the inner classes of T that inherit from B.
template getInnerClasses(T, B = Object)
{
	import std.traits, std.meta, std.string;
	auto get()
	{
		string s = "[";
		static foreach(m; __traits(allMembers, T))
		{{
			static if (m != "this")
			{
				mixin(`enum _c = __traits(compiles, isInnerClass!(T.`~m~`));`);
				static if (_c)
				{
					mixin(`alias X = T.`~m~`;`);
					static if (is(X : B))
						s ~= "`"~m~"`, ";
				}
			}
		}}
		s = s.strip(" ").strip(",")~"]";
		return s;
	}
	enum getInnerClasses = mixin(get());
}

// Generates an enum Name with members values
template genEnum(string Name, string[] values)
{
	auto gen()
	{
		import std.conv : to;
		string s = "enum "~Name~"\n{";
		static foreach(k, c; values)
			s ~= "\n\t"~c~" = "~to!string(k)~",";
		return s~"\n}";
	}
	enum genEnum = gen;
}




// Generates an enum Name with members values
template genEnum(string Name, string[] values)
{
	auto gen()
	{
		import std.conv : to;
		string s = "enum "~Name~"\n{";
		static foreach(k, c; values)
			s ~= "\n\t"~c~" = "~to!string(k)~",";
		return s~"\n}";
	}
	enum genEnum = gen;
}




/*
	A State Machine is a quasi-deterministic finite recursive structure that allows one to discretize a transitionary process in to a finite number of states. The machine can only be in any one state at any time and therefor can only take a single transition at that time and therefor the transitions are time dependent and depend upon the context.

*/


/*
	A generic State. 
	
	A state is a "black box" which can become active(entered) and act as the current state of a State Machine, 
	A state's transistions can alter depending on context and there for quite general.
*/
interface iState
{	
	alias Callback = void delegate(iState);
	string Label(string label = "");					// The label for this state. Defaults to the type's id.

	iStateMachine Machine(iStateMachine m = null);		// Gets the Machine this state is state of,
	bool IsEnterableFrom(iState);						// Determines if the state can be entered from, if arg is null then it asks if it can act as a initial start state
	bool IsExitableTo(iState);							// Determines if the state should be exited to, if arg is null then it asks if it can act as a final exit state
	void Enter();										// Called to enter the state
	void Exit();										// Called to exit the state
	void Step();										// Called to step through the state. This is used when states may have internal logic such as being a statemachine itself and/or depend on time.
	void Init();										// Called to initialize the state for the first time when the machine is created.
	void Reset();										// Called to reset the state, defaults to Init.

	Callback SetEnter(Callback c = null);				// An enter callback that can be used outside of the object for easy of use
	Callback SetExit(Callback c = null);				// An exit callback that can be used outside of the object for easy of use

}



abstract class aState : iState
{
	// The StateMachine this state is a state of. null implies it is not part of any machine
	private iStateMachine machine;
	iStateMachine Machine(iStateMachine m = null) { if (m) machine = m; return machine; }

	// The label for this state
	private string label;
	string Label(string l = "") { if (l != "") label = l; return label; }

	// The most basic possible actions of this state.
	bool IsEnterableFrom(iState) { return true; }
	bool IsExitableTo(iState) { return false; }
	void Enter() { }
	void Exit () { }
	void Step () { }
	void Init () { }
	void Reset () { Reset(); }
	
	Callback enter;
	Callback SetEnter(Callback c = null) { if (c) enter = c; return enter; }
	Callback exit;
	Callback SetExit(Callback c = null) { if (c) exit = c; return exit; }
	
	// Returns the name of this state for graphing purposes(GraphViz)
	override string toString() 
	{ 
		auto s = Label;
		iState m = machine;
		while (m !is null)
		{
			s = m.Label~"."~s;
			m = m.Machine;
		}
		return s; 
	}    
}







// The StateMachine, which is just a state(and hence can be part of another StateMachine), but contains
interface iStateMachine : iState
{
	iState CurrentState();										// Gets the current state the machine is in
	void TransAction(iState from, iState to);					// An action is called when the state machine transitions between two states
	bool Transition(iState state = null, bool force = false);	// Attempts to transition to a new state. if the state is null it attempts to transition to the unique state that passes the conditions test
	ref iState[] States();										// The States this machine contains
}






abstract class aStateMachine : aState, iStateMachine
{mixin template SetupMachine(){

		import std.traits, std.meta, std.string;
		import mDStateMachine : getInnerClasses;
		import mDGraphViz;
		import std.algorithm : max;

		// Attributes
		enum Start;					// Declares a starting state, else defaults to the first declared state

		private iState[] states;
		ref iState[] States() { return states; }

		// Add inner class states
		enum _stateNames = getInnerClasses!(typeof(this), iState);
		mixin(genEnum!("eStates", _stateNames)~"");					
		mixin("static foreach(c; _stateNames) mixin(`iState s`~c~`;`);");			// Create easy to access states(prefixed with 's')

		// If Watch is > 0, Visualization of the StateMachine is done and Watch = the time delay to wait after the machine state is viewed(to slow down the program so the states do not change too rapidly)
		int Watch = 0;

		// The starting state of the machine after a init/reset
		iState startState;

		// The current state of the machine
		iState currentState;
		iState CurrentState() { return currentState; }

		int MaxHistory = 20;	
		iState[] History;

		// Constructor
		this(bool skipEnter = false)
		{			
			static foreach(c; _stateNames)			
			{{				
				mixin(`
						auto S = new `~c~`();
						States ~= S;
						s`~c~` = S;
				`);

				if (!S.Label) S.Label = c;
				if (!S.Machine) S.Machine = this;

			}}

			Label = typeof(this).stringof;

			
			Init();
			if (!skipEnter)
				CurrentState.Enter();			
		}


		// Initalize State Machine
		override void Init()
		{
			// Set Start State
			alias start = getSymbolsByUDA!(typeof(this), Start);
			static assert(start.length < 2, "Can only have one start state");

			static if (start.length == 1)
				mixin(`currentState = States[eStates.`~(start[0]).stringof~`];`);
			else
				mixin(`currentState = States[eStates.`~(_stateNames[0])~`];`);		// Assumes array is ordered to source code

			startState = currentState;
		}

		// Step the Current State
		override void Step()
		{
			CurrentState.Step();
		}

		// Provide a default do nothing TransAction
		void TransAction(iState from, iState to) { }

		// Transition current state to next state, if arg is null it will attempt to find unique state to transition to. If force is true it will transition regardless of condition.
		bool Transition(iState state = null, bool force = false)
		{
			iState found;
			if (state)
			{
				if (force || (state.IsEnterableFrom(CurrentState) && CurrentState.IsExitableTo(state)))
					found = state;
			}
			else	
			{
				// Since state is null we check the conditions to find the unique state to transition to
				foreach(k, s; States)
					if (s.IsEnterableFrom(CurrentState) && CurrentState.IsExitableTo(s))
					{
						if (!found)
						{
							found = s;
							if (force) // Force uses the first valid state
								break;
						}						
						else
							return false;
					}
			}

			// We are able to transition to the found state
			if (found)
			{
				// Exit current state first
				auto exit = CurrentState.SetExit();
				if (exit) exit(this);

				CurrentState.Exit();
				
				// Record transition
				History ~= CurrentState;				
				auto maxHistory = max(2, MaxHistory);
				if (History.length > maxHistory*2)
				{
					History[0..maxHistory] = History[maxHistory..maxHistory*2];
					History.length = maxHistory;
				}

				TransAction(CurrentState, found);

				// Enter next state
				currentState = found;		

				CurrentState.Enter();
				auto enter = CurrentState.SetEnter();
				if (enter) enter(this);

				if (Watch != 0) View(Watch);
				return true;
			}
			return false;
		}

		




		// GraphViz the Current State of the StateMachine
		void GraphViz(string fn, iState highlight = null, iState previousState = null, string[string] options = null)
		{version(EnableGraphing){
			import std.process, std.file, std.path, std.string;
			fn = stripExtension(fn);
			if (!previousState && History.length > 0) previousState = History[$-1];
			auto g = new Directed;
			with (g) 
			{
				// Draw Nodes
				foreach(k, s; States)
				{
					string[string] opt;
					if (startState == s)
						opt = ["shape": "oval", "color": "#ff0000", "fillcolor":"red", "style":"filled"];
					else
						opt = ["shape": "oval", "color": "#334455"];

					// Highlight ith node
					if (highlight == s)
					{
						//opt["shape"] = "circle";
						opt["color"] = "#0000ff";
						opt["fillcolor"] ="blue";
						opt["style"] = "filled";
					}

					// Note one must create all the notes first because edge requires both nodes to exist
					node(s, opt);
				}

				
				// Draw edges
				foreach(s; States)
				{
					string[string] opt;
					// Add edges away from
					foreach(t; States)
					{
						if (t.IsEnterableFrom(s) && s.IsExitableTo(t))
						{
							// Highlight ith node
							if (previousState && highlight == t && previousState == s)
							{
								opt["color"] = "#2233ff";
								opt["style"] = "solid";
							} else
							{
								opt["style"] = "dashed";
							}
							edge(s, t, opt);
						}
					}
				}
			}

			//g.save(fn, true, true);			
			g.save(fn, false, false);			
		}}

		// GraphViz and View the Current State of the StateMachine
		void View(int delay = -1)
		{version(EnableGraphing){
			if (delay == -1) 
				delay = Watch;
			import std.process;
			auto fn = "__tmp__"~Label;
			GraphViz(fn, CurrentState);
			spawnShell(APNGViewer~" "~fn~".png");
			import core.thread;
			Thread.sleep(dur!"msecs"(delay));
		}}

		// Create a GraphViz Animation the History of the StateMachine
		void GraphVizHistory(string fn)
		{version(EnableGraphing){
				import std.process, std.file, std.path, std.string;
				fn = stripExtension(fn);

				import std.range, std.conv;
				string[] files;
				string fnx;
				iState previousState = null;
				foreach(k, s; History)
				{
					files ~= "__tmp__"~fn~"__"~to!string(rightJustifier(to!string(k), 4, '0').array);
					GraphViz(files[$-1], s, previousState);
					fnx ~= files[$-1]~".png ";

					previousState = s;
				}
			
				executeShell(APNGBin~"apngasm.exe "~fn~"Ani.png "~fnx~" 15");

				foreach(f; files)
					remove(f~".png");			
		}}

		// GraphVizHistory and View it
		void ViewHistory()
		{version(EnableGraphing){
			import std.process;
			auto fn = "__tmp__"~Label;
			GraphVizHistory(fn);
			executeShell(APNGViewer~" "~fn~"Ani.png");
		}}
}}

