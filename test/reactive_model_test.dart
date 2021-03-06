import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:states_rebuilder/src/inject.dart';
import 'package:states_rebuilder/src/injector.dart';
import 'package:states_rebuilder/src/reactive_model.dart';
import 'package:states_rebuilder/src/state_builder.dart';

void main() {
  ReactiveModel<Model> modelRM;

  setUp(() {
    final inject = Inject(() => Model());
    modelRM = inject.getReactive();
  });

  tearDown(() {
    modelRM = null;
  });

  test('ReactiveModel: get the state with the right status', () {
    expect(modelRM.state, isA<Model>());
    expect(modelRM.snapshot.data, isA<Model>());
    expect(modelRM.connectionState, equals(ConnectionState.none));
    expect(modelRM.hasData, isFalse);

    modelRM.setState(null);
    expect(modelRM.connectionState, equals(ConnectionState.done));
    expect(modelRM.hasData, isTrue);
  });

  test(
    'ReactiveModel: throw error if error is not caught',
    () {
      //throw
      expect(
          () => modelRM.setState((s) => s.incrementError()), throwsException);
      //do not throw
      modelRM.setState((s) => s.incrementError(), catchError: true);
    },
  );

  test('ReactiveModel: get the error', () {
    modelRM.setState((s) => s.incrementError(), catchError: true);

    expect(modelRM.error.message, equals('error message'));
    expect(
        (modelRM.snapshot.error as dynamic).message, equals('error message'));
    expect(modelRM.hasError, isTrue);
  });

  testWidgets(
    'ReactiveModel: Subscribe using StateBuilder and setState mutate the state and notify observers',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return _widgetBuilder('${modelRM.state.counter}');
        },
      );
      await tester.pumpWidget(widget);
      //
      modelRM.setState((s) => s.increment());
      await tester.pump();
      expect(find.text(('1')), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: catch sync error and notify observers',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return _widgetBuilder(
            '${modelRM.state.counter}',
            '${modelRM.error?.message}',
          );
        },
      );
      await tester.pumpWidget(widget);
      expect(find.text(('error message')), findsNothing);
      //
      modelRM.setState((s) => s.incrementError(), catchError: true);
      await tester.pump();
      expect(find.text(('error message')), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: call async method without error and notify observers',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return _widgetBuilder(
            '${modelRM.state.counter}',
            'isWaiting=${modelRM.isWaiting}',
            'isIdle=${modelRM.isIdle}',
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(find.text('0'), findsOneWidget);
      expect(find.text('isWaiting=false'), findsOneWidget);
      expect(find.text('isIdle=true'), findsOneWidget);

      modelRM.setState((s) => s.incrementAsync());
      await tester.pump();
      //isWaiting
      expect(find.text('0'), findsOneWidget);
      expect(find.text('isWaiting=true'), findsOneWidget);
      expect(find.text('isIdle=false'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      //hasData
      expect(find.text('1'), findsOneWidget);
      expect(find.text('isWaiting=false'), findsOneWidget);
      expect(find.text('isIdle=false'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: call async method with error and notify observers',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return _widgetBuilder(
            '${modelRM.hasError ? modelRM.error.message : modelRM.state.counter}',
            'isWaiting=${modelRM.isWaiting}',
            'isIdle=${modelRM.isIdle}',
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(find.text('0'), findsOneWidget);
      expect(find.text('isWaiting=false'), findsOneWidget);
      expect(find.text('isIdle=true'), findsOneWidget);

      modelRM.setState((s) => s.incrementAsyncError(), catchError: true);
      await tester.pump();
      //isWaiting
      expect(find.text('0'), findsOneWidget);
      expect(find.text('isWaiting=true'), findsOneWidget);
      expect(find.text('isIdle=false'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      //hasData
      expect(find.text('error message'), findsOneWidget);
      expect(find.text('isWaiting=false'), findsOneWidget);
      expect(find.text('isIdle=false'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: whenConnectionState should work',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return modelRM.whenConnectionState(
            onIdle: () => _widgetBuilder('onIdle'),
            onWaiting: () => _widgetBuilder('onWaiting'),
            onData: (data) => _widgetBuilder('${data.counter}'),
            onError: (error) => _widgetBuilder('${error.message}'),
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(find.text('onIdle'), findsOneWidget);

      modelRM.setState((s) => s.incrementAsync());
      await tester.pump();
      //isWaiting
      expect(find.text('onWaiting'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //hasData
      expect(find.text('1'), findsOneWidget);

      //throw error
      modelRM.setState((s) => s.incrementAsyncError());
      await tester.pump();
      //isWaiting
      expect(find.text('onWaiting'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //hasError
      expect(find.text('error message'), findsOneWidget);

      //throw error
      modelRM.setState((s) => s.incrementAsyncError());
      await tester.pump();
      //isWaiting
      expect(find.text('onWaiting'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //hasError
      expect(find.text('error message'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: with whenConnectionState error should be catch',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return modelRM.whenConnectionState(
            onIdle: () => _widgetBuilder('onIdle'),
            onWaiting: () => _widgetBuilder('onWaiting'),
            onData: (data) => _widgetBuilder('${data.counter}'),
            onError: (error) => _widgetBuilder('${error.message}'),
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(find.text('onIdle'), findsOneWidget);

      modelRM.setState((s) => s.incrementError());
      await tester.pump();
      //hasError
      expect(find.text('error message'), findsOneWidget);
      //
      modelRM.setState((s) => s.incrementError());
      await tester.pump();
      //hasError
      expect(find.text('error message'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: watch state mutating before notify observers, sync method',
    (tester) async {
      int numberOfRebuild = 0;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          numberOfRebuild++;
          return modelRM.whenConnectionState(
            onIdle: () => _widgetBuilder('onIdle'),
            onWaiting: () => _widgetBuilder('onWaiting'),
            onData: (data) => _widgetBuilder('${data.counter}'),
            onError: (error) => _widgetBuilder('${error.message}'),
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(numberOfRebuild, equals(1));
      expect(find.text('onIdle'), findsOneWidget);

      modelRM.setState(
        (s) => s.increment(),
        watch: (s) {
          return s.counter;
        },
      );
      await tester.pump();
      //will rebuild
      expect(numberOfRebuild, equals(2));
      expect(find.text('1'), findsOneWidget);
      //will not rebuild
      modelRM.setState(
        (s) => s.increment(),
        watch: (s) {
          return 1;
        },
      );
      await tester.pump();
      //
      expect(numberOfRebuild, equals(2));
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: watch state mutating before notify observers, async method',
    (tester) async {
      int numberOfRebuild = 0;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          numberOfRebuild++;
          return modelRM.whenConnectionState(
            onIdle: () => _widgetBuilder('onIdle'),
            onWaiting: () => _widgetBuilder('onWaiting'),
            onData: (data) => _widgetBuilder('${data.counter}'),
            onError: (error) => _widgetBuilder('${error.message}'),
          );
        },
      );
      await tester.pumpWidget(widget);

      expect(numberOfRebuild, equals(1));
      expect(find.text('onIdle'), findsOneWidget);

      modelRM.setState(
        (s) => s.incrementAsync(),
        watch: (s) {
          return 0;
        },
      );
      await tester.pump();
      //will not rebuild
      expect(numberOfRebuild, equals(1));
      expect(find.text('onIdle'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //will not rebuild
      expect(numberOfRebuild, equals(1));
      expect(find.text('onIdle'), findsOneWidget);

      //
      modelRM.setState(
        (s) => s.incrementAsync(),
        watch: (s) {
          return s.counter;
        },
      );
      await tester.pump();
      //will not rebuild
      expect(numberOfRebuild, equals(1));
      expect(find.text('onIdle'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //will rebuild
      expect(numberOfRebuild, equals(2));
      expect(find.text('2'), findsOneWidget);

      //
      modelRM.setState(
        (s) => s.incrementAsync(),
        watch: (s) {
          return 1;
        },
      );
      await tester.pump();
      //will not rebuild
      expect(numberOfRebuild, equals(2));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //will not rebuild
      expect(numberOfRebuild, equals(2));
      expect(find.text('2'), findsOneWidget);

      //
      modelRM.setState(
        (s) => s.incrementAsync(),
        watch: (s) {
          return s.counter;
        },
      );
      await tester.pump();
      //will not rebuild
      expect(numberOfRebuild, equals(2));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(Duration(seconds: 1));
      //will rebuild
      expect(numberOfRebuild, equals(3));
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: tagFilter works',
    (tester) async {
      final widget = StateBuilder(
        models: [modelRM],
        tag: 'tag1',
        builder: (_, __) {
          return modelRM.whenConnectionState(
            onIdle: () => _widgetBuilder('onIdle'),
            onWaiting: () => _widgetBuilder('onWaiting'),
            onData: (data) => _widgetBuilder('${data.counter}'),
            onError: (error) => _widgetBuilder('${error.message}'),
          );
        },
      );
      await tester.pumpWidget(widget);
      //isIdle
      expect(find.text('onIdle'), findsOneWidget);
      //rebuildAll
      modelRM.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      //rebuild with tag 'tag1'
      modelRM.setState((s) => s.increment(), filterTags: ['tag1']);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      //rebuild with tag 'nonExistingTag'
      modelRM.setState((s) => s.increment(), filterTags: ['nonExistingTag']);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel: onSetState and onRebuildState work',
    (tester) async {
      int numberOfOnSetStateCall = 0;
      int numberOfOnRebuildStateCall = 0;
      BuildContext contextFromOnSetState;
      BuildContext contextFromOnRebuildState;
      String lifeCycleTracker = '';
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          lifeCycleTracker += 'build, ';
          return Container();
        },
      );
      await tester.pumpWidget(widget);
      expect(numberOfOnSetStateCall, equals(0));
      //
      modelRM.setState(
        (s) => s.increment(),
        onSetState: (context) {
          numberOfOnSetStateCall++;
          contextFromOnSetState = context;
          lifeCycleTracker += 'onSetState, ';
        },
        onRebuildState: (context) {
          numberOfOnRebuildStateCall++;
          contextFromOnRebuildState = context;
          lifeCycleTracker += 'onRebuildState, ';
        },
      );
      await tester.pump();
      expect(numberOfOnSetStateCall, equals(1));
      expect(contextFromOnSetState, isNotNull);
      expect(numberOfOnRebuildStateCall, equals(1));
      expect(contextFromOnRebuildState, isNotNull);
      expect(lifeCycleTracker,
          equals('build, onSetState, build, onRebuildState, '));
    },
  );

  testWidgets(
    'ReactiveModel: onData work for sync call',
    (tester) async {
      int numberOfOnDataCall = 0;
      BuildContext contextFromOnData;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return Container();
        },
      );
      await tester.pumpWidget(widget);
      expect(numberOfOnDataCall, equals(0));
      expect(contextFromOnData, isNull);
      //
      modelRM.setState(
        (s) => s.increment(),
        onData: (context, data) {
          contextFromOnData = context;
          numberOfOnDataCall++;
        },
      );
      await tester.pump();
      expect(numberOfOnDataCall, equals(1));
      expect(contextFromOnData, isNotNull);
    },
  );

  testWidgets(
    'ReactiveModel: onData work for async call',
    (tester) async {
      int numberOfOnDataCall = 0;
      BuildContext contextFromOnData;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return Container();
        },
      );
      await tester.pumpWidget(widget);
      expect(numberOfOnDataCall, equals(0));
      expect(contextFromOnData, isNull);

      //
      modelRM.setState(
        (s) => s.incrementAsync(),
        onData: (context, data) {
          contextFromOnData = context;
          numberOfOnDataCall++;
        },
      );
      await tester.pump();
      expect(numberOfOnDataCall, equals(0));
      await tester.pump(Duration(seconds: 1));
      expect(numberOfOnDataCall, equals(1));
      expect(contextFromOnData, isNotNull);
    },
  );

  testWidgets(
    'ReactiveModel: onError work for sync call',
    (tester) async {
      int numberOfOnErrorCall = 0;
      BuildContext contextFromOnError;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return Container();
        },
      );
      await tester.pumpWidget(widget);
      expect(numberOfOnErrorCall, equals(0));
      expect(contextFromOnError, isNull);
      //
      modelRM.setState(
        (s) => s.incrementError(),
        onError: (context, data) {
          numberOfOnErrorCall++;
          contextFromOnError = context;
        },
      );
      await tester.pump();
      expect(numberOfOnErrorCall, equals(1));
      expect(contextFromOnError, isNotNull);
    },
  );

  testWidgets(
    'ReactiveModel: onError work for async call',
    (tester) async {
      int numberOfOnErrorCall = 0;
      BuildContext contextFromOnError;
      final widget = StateBuilder(
        models: [modelRM],
        builder: (_, __) {
          return Container();
        },
      );
      await tester.pumpWidget(widget);
      expect(numberOfOnErrorCall, equals(0));
      expect(contextFromOnError, isNull);
      //
      modelRM.setState(
        (s) => s.incrementAsyncError(),
        onError: (context, data) {
          numberOfOnErrorCall++;
          contextFromOnError = context;
        },
      );
      await tester.pump();
      expect(numberOfOnErrorCall, equals(0));
      expect(contextFromOnError, isNull);
      //
      await tester.pump(Duration(seconds: 1));
      expect(numberOfOnErrorCall, equals(1));
      expect(contextFromOnError, isNotNull);
    },
  );

  testWidgets(
    'ReactiveModel: onSetState and onRebuildState work with context registered models',
    (tester) async {
      int numberOfOnSetStateCall = 0;
      int numberOfOnRebuildStateCall = 0;
      BuildContext contextFromOnSetState;
      BuildContext contextFromOnRebuildState;
      String lifeCycleTracker = '';
      ReactiveModel<Model> modelRM;
      final widget = Injector(
        inject: [Inject(() => Model())],
        builder: (context) {
          modelRM = Injector.getAsReactive(context: context);
          lifeCycleTracker += 'build, ';
          return Container();
        },
      );

      await tester.pumpWidget(widget);
      expect(numberOfOnSetStateCall, equals(0));
      //
      modelRM.setState(
        (s) => s.increment(),
        onSetState: (context) {
          numberOfOnSetStateCall++;
          contextFromOnSetState = context;
          lifeCycleTracker += 'onSetState, ';
        },
        onRebuildState: (context) {
          numberOfOnRebuildStateCall++;
          contextFromOnRebuildState = context;
          lifeCycleTracker += 'onRebuildState, ';
        },
      );
      await tester.pump();
      expect(numberOfOnSetStateCall, equals(1));
      expect(contextFromOnSetState, isNotNull);
      expect(numberOfOnRebuildStateCall, equals(1));
      expect(contextFromOnRebuildState, isNotNull);
      expect(lifeCycleTracker,
          equals('build, onSetState, build, onRebuildState, '));
    },
  );

  testWidgets(
    'ReactiveModel: onSetState context is obtained from the InheritedWidget',
    (tester) async {
      BuildContext contextFromOnSetState;
      BuildContext contextFromBuilder;
      BuildContext contextFromBuilder2;
      ReactiveModel<Model> modelRM;
      final widget = Injector(
        inject: [Inject(() => Model())],
        builder: (context) {
          modelRM = Injector.getAsReactive(context: context);
          return StateBuilder(
            models: [modelRM],
            builder: (context, _) {
              contextFromBuilder = context;
              return StateBuilder(
                models: [modelRM],
                builder: (context, _) {
                  contextFromBuilder2 = context;
                  return Container();
                },
              );
            },
          );
        },
      );

      await tester.pumpWidget(widget);

      //
      modelRM.setState(
        (s) => s.increment(),
        onSetState: (context) {
          contextFromOnSetState = context;
        },
      );
      await tester.pump();
      assert(contextFromBuilder != contextFromOnSetState, isTrue);
      assert(contextFromBuilder2 != contextFromOnSetState, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : reactive singleton and reactive instances works independently',
    (tester) async {
      final inject = Inject(() => Model());
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);
      //
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //mutate singleton
      modelRM0.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-3'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel : new reactive notify reactive singleton with its state if joinSingleton = withNewReactiveInstance',
    (tester) async {
      final inject = Inject(
        () => Model(),
        joinSingleton: JoinSingleton.withNewReactiveInstance,
      );
      final modelRM2 = inject.getReactive(true);
      final modelRM1 = inject.getReactive(true);
      final modelRM0 = inject.getReactive();

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment());
      await tester.pump();

      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //mutate reactive instance 1
      modelRM2.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);
    },
  );

  testWidgets(
    'ReactiveModel : singleton holds the combined state of new instances if joinSingleton = withCombinedReactiveInstances case sync with error call',
    (tester) async {
      final inject = Inject(
        () => Model(),
        joinSingleton: JoinSingleton.withCombinedReactiveInstances,
      );
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(modelRM0.isIdle, isTrue);
      expect(modelRM1.isIdle, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.isIdle, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.incrementError());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.incrementError());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-1'), findsOneWidget);

      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-1'), findsOneWidget);

      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.increment());
      await tester.pump();
      expect(find.text('modelRM0-3'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-3'), findsOneWidget);

      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : singleton holds the combined state of new instances if joinSingleton = withCombinedReactiveInstances case async wth error call',
    (tester) async {
      final inject = Inject(
        () => Model(),
        joinSingleton: JoinSingleton.withCombinedReactiveInstances,
      );
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.incrementAsyncError());
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);
      expect(modelRM1.isWaiting, isTrue);
      expect(modelRM2.isIdle, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.incrementAsyncError());
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      expect(modelRM0.isWaiting, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.incrementAsync());
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);
      expect(modelRM1.isWaiting, isTrue);
      expect(modelRM2.hasError, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.incrementAsync());
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-1'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : join singleton to new reactive from setState',
    (tester) async {
      final inject = Inject(() => Model());
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //mutate reactive instance 1
      modelRM1.setState(
        (s) => s.incrementError(),
        joinSingleton: true,
        catchError: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 2
      modelRM2.setState(
        (s) => s.incrementError(),
        joinSingleton: true,
        catchError: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.hasError, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment(), joinSingleton: true);
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.increment(), joinSingleton: true);
      await tester.pump();
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.hasData, isTrue);
      expect(modelRM2.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : notify all reactive instances to new reactive from setState',
    (tester) async {
      final inject = Inject(() => Model());
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //mutate reactive instance 0
      modelRM0.setState(
        (s) => s.incrementError(),
        notifyAllReactiveInstances: true,
        catchError: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-0'), findsOneWidget);
      expect(find.text('modelRM1-0'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
      expect(modelRM1.isIdle, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 0
      modelRM0.setState(
        (s) => s.increment(),
        notifyAllReactiveInstances: true,
        catchError: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.isIdle, isTrue);
      expect(modelRM2.isIdle, isTrue);

      //mutate reactive instance 1
      modelRM2.setState(
        (s) => s.incrementError(),
        notifyAllReactiveInstances: true,
        catchError: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.isIdle, isTrue);
      expect(modelRM2.hasError, isTrue);

      //mutate reactive instance 0
      modelRM2.setState(
        (s) => s.increment(),
        notifyAllReactiveInstances: true,
      );
      await tester.pump();
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
      expect(modelRM1.isIdle, isTrue);
      expect(modelRM2.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : join singleton to new reactive from setState with data send using joinSingletonToNewData',
    (tester) async {
      final inject = Inject(() => Model());
      final modelRM0 = inject.getReactive();
      final modelRM1 = inject.getReactive(true);
      final modelRM2 = inject.getReactive(true);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder(
                  'modelRM0-${modelRM0.joinSingletonToNewData}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //mutate reactive instance 1
      modelRM1.setState((s) => s.increment(),
          joinSingleton: true,
          catchError: true,
          joinSingletonToNewData: () => 'modelRM1-${modelRM1.state.counter}');
      await tester.pump();
      expect(find.text('modelRM0-modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //mutate reactive instance 2
      modelRM2.setState((s) => s.increment(),
          joinSingleton: true,
          catchError: true,
          joinSingletonToNewData: () => 'modelRM2-${modelRM1.state.counter}');
      await tester.pump();
      expect(find.text('modelRM0-modelRM2-2'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);
    },
  );

  testWidgets(
      'ReactiveModel : throws if setState is called on async injected models',
      (tester) async {
    final inject = Inject.future(() => getFuture());
    final modelRM0 = inject.getReactive();
    expect(() => modelRM0.setState(null), throwsException);
    await tester.pump(Duration(seconds: 1));
  });

  testWidgets(
    'ReactiveModel : inject futures with data works',
    (tester) async {
      final inject = Inject.future(() => getFuture());
      final modelRM0 = inject.getReactive();

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('${modelRM0.state}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(find.text('null'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : inject futures with error works',
    (tester) async {
      final inject = Inject.future(() => getFutureWithError());
      final modelRM0 = inject.getReactive();

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('${modelRM0.state}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(find.text('null'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('null'), findsOneWidget);
      expect(modelRM0.hasError, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : inject futures with tag filter works ',
    (tester) async {
      final inject = Inject.future(() => getFuture(), filterTags: ['tag1']);
      final modelRM0 = inject.getReactive();

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            tag: 'tag1',
            builder: (context, _) {
              return _widgetBuilder('tag1-${modelRM0.state}');
            },
          ),
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('${modelRM0.state}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(find.text('tag1-null'), findsOneWidget);
      expect(find.text('null'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('tag1-1'), findsOneWidget);
      expect(find.text('null'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);
    },
  );

  testWidgets(
    'ReactiveModel : inject stream with data works',
    (tester) async {
      final inject = Inject.stream(() => getStream(), initialValue: 0);
      final modelRM0 = inject.getReactive();

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('${modelRM0.state}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(find.text('0'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('0'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      // expect(modelRM0.isStreamDone, isTrue);TODO stream should be done
    },
  );

  testWidgets(
    'ReactiveModel : inject stream with watching data works',
    (tester) async {
      final inject = Inject.stream(() => getStream(), watch: (data) {
        return 0;
      });
      final modelRM0 = inject.getReactive();
      int numberOfRebuild = 0;
      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              numberOfRebuild++;
              return _widgetBuilder('${modelRM0.state}-$numberOfRebuild');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      expect(find.text('null-1'), findsOneWidget);
      expect(modelRM0.isWaiting, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('null-1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('null-1'), findsOneWidget);
      expect(modelRM0.hasData, isTrue);

      await tester.pump(Duration(seconds: 1));
      expect(find.text('null-1'), findsOneWidget);
    },
  );

  group('ReactiveModel setValue :', () {
    testWidgets(
      'tagFilter works',
      (tester) async {
        final modelRM = ReactiveModel.create(0);

        final widget = StateBuilder(
          models: [modelRM],
          tag: 'tag1',
          builder: (_, __) {
            return _widgetBuilder('${modelRM.value}');
          },
        );
        await tester.pumpWidget(widget);
        modelRM.setValue(() => modelRM.value + 1);
        await tester.pump();
        expect(find.text(('1')), findsOneWidget);

        await tester.pumpWidget(widget);
        modelRM.setValue(() => modelRM.value + 1, filterTags: ['tag1']);
        await tester.pump();
        expect(find.text(('2')), findsOneWidget);
        await tester.pumpWidget(widget);
        modelRM
            .setValue(() => modelRM.value + 1, filterTags: ['nonExistingTag']);
        await tester.pump();
        expect(find.text(('2')), findsOneWidget);
      },
    );

    testWidgets(
      'if the value does not changed do not rebuild',
      (tester) async {
        final modelRM = ReactiveModel.create(0);
        int numberOfRebuild = 0;
        final widget = StateBuilder(
          models: [modelRM],
          tag: 'tag1',
          builder: (_, __) {
            return _widgetBuilder('${++numberOfRebuild}');
          },
        );
        await tester.pumpWidget(widget);
        expect(find.text(('1')), findsOneWidget);

        modelRM.setValue(() => modelRM.value);
        await tester.pump();
        expect(find.text(('1')), findsOneWidget);

        modelRM.setValue(() => modelRM.value + 1);
        await tester.pump();
        expect(find.text(('2')), findsOneWidget);
      },
    );

    testWidgets(
      'onSetState and onRebuildState work',
      (tester) async {
        final modelRM = ReactiveStatesRebuilder<int>(Inject(() => 0));

        int numberOfOnSetStateCall = 0;
        int numberOfOnRebuildStateCall = 0;
        BuildContext contextFromOnSetState;
        BuildContext contextFromOnRebuildState;
        String lifeCycleTracker = '';
        final widget = StateBuilder(
          models: [modelRM],
          builder: (_, __) {
            lifeCycleTracker += 'build, ';
            return Container();
          },
        );
        await tester.pumpWidget(widget);
        expect(numberOfOnSetStateCall, equals(0));
        //
        modelRM.setValue(
          () => modelRM.value + 1,
          onSetState: (context) {
            numberOfOnSetStateCall++;
            contextFromOnSetState = context;
            lifeCycleTracker += 'onSetState, ';
          },
          onRebuildState: (context) {
            numberOfOnRebuildStateCall++;
            contextFromOnRebuildState = context;
            lifeCycleTracker += 'onRebuildState, ';
          },
        );
        await tester.pump();
        expect(numberOfOnSetStateCall, equals(1));
        expect(contextFromOnSetState, isNotNull);
        expect(numberOfOnRebuildStateCall, equals(1));
        expect(contextFromOnRebuildState, isNotNull);
        expect(lifeCycleTracker,
            equals('build, onSetState, build, onRebuildState, '));
      },
    );

    testWidgets(
      'sync methods with and without error work',
      (tester) async {
        final modelRM = ReactiveModel.create(0);

        final widget = StateBuilder(
          models: [modelRM],
          builder: (_, __) {
            return modelRM.whenConnectionState(
              onIdle: () => _widgetBuilder('onIdle'),
              onWaiting: () => _widgetBuilder('onWaiting'),
              onData: (data) => _widgetBuilder('${data}'),
              onError: (error) => _widgetBuilder('${error.message}'),
            );
          },
        );
        await tester.pumpWidget(widget);
        //sync increment without error
        modelRM.setValue(() {
          final model = Model();
          model.increment();
          return model.counter;
        });
        await tester.pump();
        expect(find.text(('1')), findsOneWidget);

        //sync increment with error
        var error;
        modelRM.setValue(
          () {
            final model = Model();
            model.incrementError();
            return model.counter;
          },
          onError: (_, e) {
            error = e;
          },
          catchError: true,
        );
        await tester.pump();
        expect(find.text('error message'), findsOneWidget);
        expect(error.message, equals('error message'));
      },
    );

    testWidgets(
      'seeds works',
      (tester) async {
        final modelRM0 = ReactiveModel.create(0);
        final modelRM1 = modelRM0.asNew('seed1');

        final widget = Column(
          children: <Widget>[
            StateBuilder(
              models: [modelRM0],
              builder: (_, __) {
                return _widgetBuilder('model0-${modelRM0.value}');
              },
            ),
            StateBuilder(
              models: [modelRM1],
              builder: (_, __) {
                return _widgetBuilder('model1-${modelRM1.value}');
              },
            )
          ],
        );
        await tester.pumpWidget(widget);
        modelRM0.setValue(() => modelRM0.value + 1);
        await tester.pump();
        expect(find.text(('model0-1')), findsOneWidget);
        expect(find.text(('model1-0')), findsOneWidget);
        //
        modelRM0.setValue(() => modelRM0.value + 1, seeds: ['seed1']);
        await tester.pump();
        expect(find.text(('model0-2')), findsOneWidget);
        expect(find.text(('model1-2')), findsOneWidget);
        //
        modelRM1.setValue(() => modelRM1.value + 1,
            notifyAllReactiveInstances: true);
        await tester.pump();
        expect(find.text(('model0-3')), findsOneWidget);
        expect(find.text(('model1-3')), findsOneWidget);
      },
    );

    // testWidgets(//TODO make it work for async methods
    //   'Async methods with and without error work',
    //   (tester) async {
    //     final modelRM = ReactiveModel.create(0);

    //     final widget = StateBuilder(
    //       models: [modelRM],
    //       builder: (_, __) {
    //         return modelRM.whenConnectionState(
    //           onIdle: () => _widgetBuilder('onIdle'),
    //           onWaiting: () => _widgetBuilder('onWaiting'),
    //           onData: (data) => _widgetBuilder('${data}'),
    //           onError: (error) => _widgetBuilder('${error.message}'),
    //         );
    //       },
    //     );
    //     await tester.pumpWidget(widget);
    //     //sync increment without error
    //     modelRM.setValue(() async {
    //       final model = Model();
    //       await model.incrementAsync();
    //       return model.counter;
    //     });
    //     await tester.pump();
    //     expect(find.text(('0')), findsOneWidget);

    //     await tester.pump(Duration(seconds: 1));
    //     expect(find.text(('1')), findsOneWidget);

    //     // //sync increment with error
    //     // modelRM.setValue(() {
    //     //   final model = Model();
    //     //   model.incrementError();
    //     //   return model.counter;
    //     // });
    //     // await tester.pump();
    //     // // expect(find.text('error message'), findsOneWidget);
    //   },
    // );
    //
  });

  test(
      'ReactiveModel: get new reactive model with the same seed returns the same instance',
      () {
    //get new reactive instance with the default seed
    final modelNewRM1 = modelRM.asNew();

    expect(modelNewRM1, isA<ReactiveModel>());
    expect(modelRM != modelNewRM1, isTrue);
    ////get another new reactive instance with the default seed
    final modelNewRM2 = modelRM.asNew();
    expect(modelNewRM2, isA<ReactiveModel>());
    expect(modelNewRM2 == modelNewRM1, isTrue);

    //get new reactive instance with the custom seed
    final modelNewRM3 = modelRM.asNew(Seeds.seed1);

    expect(modelNewRM3, isA<ReactiveModel>());
    expect(modelNewRM3 != modelNewRM1, isTrue);
    ////get another new reactive instance with the default seed
    final modelNewRM4 = modelRM.asNew(Seeds.seed1);
    expect(modelNewRM4, isA<ReactiveModel>());
    expect(modelNewRM4 == modelNewRM3, isTrue);
  });

  test('ReactiveModel: get new reactive instance always return', () {
    final modelNewRM1 = modelRM.asNew();
    final modelNewRM2 = modelNewRM1.asNew();
    expect(modelNewRM1 == modelNewRM2, isTrue);
  });

  test('ReactiveModel: ReactiveModel.create works ', () {
    final _modelRM = ReactiveModel.create(1);
    expect(_modelRM, isA<ReactiveModel>());
    _modelRM.setValue(() => _modelRM.value + 1);
    expect(_modelRM.value, equals(2));
  });

  testWidgets(
    'ReactiveModel : reactive singleton and reactive instances work with seed',
    (tester) async {
      final inject = Inject(() => Model());
      final modelRM0 = inject.getReactive();
      final modelRM1 = modelRM0.asNew(Seeds.seed1);
      final modelRM2 = modelRM1.asNew(Seeds.seed2);

      final widget = Column(
        children: <Widget>[
          StateBuilder(
            models: [modelRM0],
            builder: (context, _) {
              return _widgetBuilder('modelRM0-${modelRM0.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM1],
            builder: (context, _) {
              return _widgetBuilder('modelRM1-${modelRM1.state.counter}');
            },
          ),
          StateBuilder(
            models: [modelRM2],
            builder: (context, _) {
              return _widgetBuilder('modelRM2-${modelRM2.state.counter}');
            },
          )
        ],
      );

      await tester.pumpWidget(widget);

      //
      modelRM0.setState((s) => s.increment(), seeds: [Seeds.seed1]);
      await tester.pump();
      expect(find.text('modelRM0-1'), findsOneWidget);
      expect(find.text('modelRM1-1'), findsOneWidget);
      expect(find.text('modelRM2-0'), findsOneWidget);

      //
      modelRM0.setState((s) => s.increment(),
          seeds: [Seeds.seed1, Seeds.seed2, 'nonExistingSeed']);
      await tester.pump();
      expect(find.text('modelRM0-2'), findsOneWidget);
      expect(find.text('modelRM1-2'), findsOneWidget);
      expect(find.text('modelRM2-2'), findsOneWidget);

      //
      modelRM0.setState((s) => s.increment(), notifyAllReactiveInstances: true);
      await tester.pump();
      expect(find.text('modelRM0-3'), findsOneWidget);
      expect(find.text('modelRM1-3'), findsOneWidget);
      expect(find.text('modelRM2-3'), findsOneWidget);
    },
  );

  test('ReactiveStatesRebuilder throws if inject is null ', () {
    expect(() => ReactiveStatesRebuilder(null), throwsAssertionError);
  });
}

class Model {
  int counter = 0;

  void increment() {
    counter++;
  }

  void incrementError() {
    throw Exception('error message');
  }

  void incrementAsync() async {
    await getFuture();
    counter++;
  }

  void incrementAsyncError() async {
    await getFuture();
    throw Exception('error message');
  }
}

Widget _widgetBuilder(String text1, [String text2, String text3]) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: <Widget>[
        Text(text1 ?? ''),
        Text(text2 ?? ''),
        Text(text3 ?? ''),
      ],
    ),
  );
}

Future<int> getFuture() => Future.delayed(Duration(seconds: 1), () => 1);
Future<int> getFutureWithError() => Future.delayed(
    Duration(seconds: 1), () => throw Exception('error message'));
Stream<int> getStream() =>
    Stream.periodic(Duration(seconds: 1), (num) => num).take(3);

enum Seeds { seed1, seed2 }
