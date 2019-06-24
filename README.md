# DStateMachine
A Simple State Machine For The D Language. 

Uses GraphViz to graph the state of the Statemachine for visualization.


# Simple 3-State Sequential Machine

The following is a simple example of a 3-state machine that sequentially transitions between the states

	class MyStateMachine : aStateMachine
	{
		mixin SetupMachine;

		void TransAction(iState from, iState to) { writeln("----"); }
		class State1 : aState
		{
			override bool IsEnterableFrom(iState s) { if (s == sState3) return true; return false; }
			override bool IsExitableTo(iState s) { if (s == sState2) return true; return false; }
			override void Enter() { writeln("Entered "~Label); }
			override void Exit() { writeln("Exited "~Label); }
			override void Step() { writeln("Step "~Label); }
		}

		class State2 : aState
		{
			override bool IsEnterableFrom(iState s) { if (s == sState1) return true; return false; }
			override bool IsExitableTo(iState s) { if (s == sState3) return true; return false; }
			override void Enter() { writeln("Entered "~Label); }
			override void Exit() { writeln("Exited "~Label); }
			override void Step() { writeln("Step "~Label); }
		}

		class State3 : aState
		{
			override bool IsEnterableFrom(iState s) { if (s == sState2) return true; return false; }
			override bool IsExitableTo(iState s) { if (s == sState1) return true; return false; }
			override void Enter() { writeln("Entered "~Label); }
			override void Exit() { writeln("Exited "~Label); }      
			override void Step() { writeln("Step "~Label); }
		}
	}
  
  DStateMachine can output a GraphViz of the state machine at runtime either based on the history of the state machine(useful for debugging purposes) or the current state.
  
  ![Simple Machine](https://raw.githubusercontent.com/TheUniversalInvariant/DStateMachine/master/MyStateMachineAni.png)
