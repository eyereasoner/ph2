% --------------------
% Marble -- Jos De Roo
% --------------------
%
% See https://github.com/eyereasoner/marble#readme
%

:- use_module(library(between)).
:- use_module(library(format)).
:- use_module(library(iso_ext)).
:- use_module(library(lists)).
:- use_module(library(terms)).

:- dynamic(brake/0).
:- dynamic(label/1).
:- dynamic(pred/1).
:- dynamic(implies/2).
:- dynamic(answer/1).
:- dynamic('<http://www.w3.org/2000/10/swap/log#onPositiveSurface>'/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#onNeutralSurface>'/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'/2).

version_info('Marble v0.6.0').

% run
run :-
    version_info(Version),
    format("% Processed by ~w~n", [Version]),
    catch(forward, Exc,
        (   writeq(Exc),
            write('.'),
            nl,
            (   Exc = inference_fuse(_,_)
            ->  halt(2)
            ;   halt(1)
            )
        )
    ),
    (   answer(Answer),
        (   Answer = exopred(P, S, O)
        ->  P \= implies,
            T =.. [P, S, O]
        ;   T = Answer
        ),
        writeq(T),
        write('.'),
        nl,
        fail
    ;   halt(0)
    ).

% forward chaining
forward :-
    implies(Prem, Conc),
    Prem,
    (   Conc = ':-'(C, P)
    ->  \+clause(C, P)
    ;   \+Conc
    ),
    (   Conc \= implies(_, _),
        Conc \= ':-'(_, _)
    ->  labelvars(Conc)
    ;   true
    ),
    astep(Conc),
    retract(brake),
    fail.
forward :-
    (   brake
    ->  !
    ;   assertz(brake),
        forward
    ).

% create witnesses
labelvars(Term) :-
    (   retract(label(Current))
    ->  true
    ;   Current = 0
    ),
    numbervars(Term, Current, Next),
    assertz(label(Next)).

% assert new step
astep((A, B)) :-
    !,
    astep(A),
    astep(B).
astep(A) :-
    (   (   A = ':-'(C, P)
        ->  \+clause(C, P)
        ;   \+A
        )
    ->  assertz(A),
        (   functor(A, B, 2),
            \+pred(B)
        ->  assertz(pred(B))
        ;   true
        )
    ;   true
    ).

% assert positive surface
implies('<http://www.w3.org/2000/10/swap/log#onPositiveSurface>'(_, G), G).

% blow inference fuse
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        makevars(G, H, V),
        catch(call(H), _, false)
        ), throw(inference_fuse('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G), H))).

% resolve positive surface
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        select('<http://www.w3.org/2000/10/swap/log#onPositiveSurface>'([], H), L, K),
        conj_list(H, D),
        append(K, D, E),
        conj_list(F, E)
        ), '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, F)).

% erase at even level
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        select('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'([], H), L, K),
        conj_list(H, M),
        select('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'([], O), M, N),
        (   conj_list(O, D),
            append(K, D, E),
            conj_list(C, E)
        ;   length(K, I),
            I > 1,
            conj_list(F, N),
            conj_list(C, ['<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'([], F)|K])
        )), '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, C)).

% non-unit resolution
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        \+member('<http://www.w3.org/2000/10/swap/log#onPositiveSurface>'(_, _), L),
        \+member('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'(_, _), L),
        length(L, E),
        E < 4,
        '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(W, F),
        conj_list(F, K),
        length(K, 2),
        \+ (member('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(_, I), K), atomic(I)),
        makevars(K, J, W),
        select('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(U, C), J, [P]),
        (   select('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(_, P), L, M),
            conj_list(H, ['<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(U, C)|M])
        ;   select(C, L, M),
            conj_list(H, [P|M])
        ),
        ground('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, H))
        ), '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, H)).

% factoring
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        list_to_set(L, M),
        conj_list(H, M)
        ), '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, H)).

% adjust graffiti
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        findvars(G, U),
        findall(M,
            (   member(M, V),
                memberchk(M, U)
            ),
            W
        ),
        W \= V
        ), '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(W, G)).

% forward rule
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        select('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(_, H), L, K),
        conj_list(R, K),
        domain(V, R, P),
        makevars([P, H], [Q, S], V),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, I)).

% contrapositive
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        \+member('<http://www.w3.org/2000/10/swap/log#onPositiveSurface>'(_, _), L),
        \+member('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(_, _), L),
        \+member('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'(_, _), L),
        select(R, L, J),
        conj_list(T, J),
        E = '<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'([], T),
        domain(V, R, P),
        makevars([P, E], [Q, S], V),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, I)).

% backward rule
implies(('<http://www.w3.org/2000/10/swap/log#onNegativeSurface>'(V, G),
        conj_list(G, L),
        select('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'(_, H), L, K),
        conj_list(H, [T]),
        conj_list(R, K),
        makevars(':-'(T, R), C, V)
        ), C).

% query
implies(('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'(V, G),
        conj_list(G, L),
        (   select('<http://www.w3.org/2000/10/swap/log#onQuerySurface>'(_, H), L, K)
        ->  conj_list(P, K)
        ;   P = G,
            H = G
        ),
        makevars([P, H], [Q, S], V),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, answer(I))).

%
% built-ins
%

% graph
'<http://www.w3.org/2000/10/swap/graph#list>'(A, B) :-
    conj_list(A, B).

% list
'<http://www.w3.org/2000/10/swap/list#append>'(A, B) :-
    append(A, B).

'<http://www.w3.org/2000/10/swap/list#first>'([A|_], A) .

'<http://www.w3.org/2000/10/swap/list#firstRest>'([A|B], [A, B]).

'<http://www.w3.org/2000/10/swap/list#in>'(A, B) :-
    member(A, B).

'<http://www.w3.org/2000/10/swap/list#iterate>'(A, [B, C]) :-
    nth0(B, A, C).

'<http://www.w3.org/2000/10/swap/list#last>'(A, B) :-
    append(_, [B], A).

'<http://www.w3.org/2000/10/swap/list#length>'(A, B) :-
    length(A, B).

'<http://www.w3.org/2000/10/swap/list#map>'([A, B], C) :-
    findall(E,
        (   member(F, A),
            G =.. [B, F, E],
            G
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#member>'(A, B) :-
    member(B, A).

'<http://www.w3.org/2000/10/swap/list#memberAt>'([A, B], C) :-
    nth0(B, A, C).

'<http://www.w3.org/2000/10/swap/list#remove>'([A, B], C) :-
    findall(I,
        (   member(I, A),
            I \= B
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#removeAt>'([A, B], C) :-
    nth0(B, A, D),
    findall(I,
        (   member(I, A),
            I \= D
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#removeDuplicates>'(A, B) :-
    list_to_set(A, B).

'<http://www.w3.org/2000/10/swap/list#rest>'([_|A], A).

%log
'<http://www.w3.org/2000/10/swap/log#bound>'(X, Y) :-
    (   nonvar(X)
    ->  Y = true
    ;   Y = false
    ).

'<http://www.w3.org/2000/10/swap/log#callWithCleanup>'(A, B) :-
    call_cleanup(A, B).

'<http://www.w3.org/2000/10/swap/log#callWithOptional>'(A, B) :-
    call(A),
    (   \+catch(call(B), _, fail)
    ->  true
    ;   catch(call(B), _, fail)
    ).

'<http://www.w3.org/2000/10/swap/log#collectAllIn>'([A, B, C], _) :-
    catch(findall(A, B, E), _, E = []),
    E = C.

'<http://www.w3.org/2000/10/swap/log#equalTo>'(X, Y) :-
    X = Y.

'<http://www.w3.org/2000/10/swap/log#forAllIn>'([A, B], _) :-
    forall(A, B).

'<http://www.w3.org/2000/10/swap/log#graffiti>'(A, B) :-
    term_variables(A, B).

'<http://www.w3.org/2000/10/swap/log#ifThenElseIn>'([A, B, C], _) :-
    if_then_else(A, B, C).

'<http://www.w3.org/2000/10/swap/log#notEqualTo>'(X, Y) :-
    X \= Y.

'<http://www.w3.org/2000/10/swap/log#repeat>'(A, B) :-
    C is A-1,
    between(0, C, B).

% math
'<http://www.w3.org/2000/10/swap/math#absoluteValue>'(X, Y) :-
    Y is abs(X).

'<http://www.w3.org/2000/10/swap/math#acos>'(X, Y) :-
    Y is acos(X).

'<http://www.w3.org/2000/10/swap/math#asin>'(X, Y) :-
    Y is asin(X).

'<http://www.w3.org/2000/10/swap/math#atan>'(X, Y) :-
    Y is atan(X).

'<http://www.w3.org/2000/10/swap/math#atan2>'([X, Y], Z) :-
    Z is atan(X/Y).

'<http://www.w3.org/2000/10/swap/math#ceiling>'(X, Y) :-
    Y is ceiling(X).

'<http://www.w3.org/2000/10/swap/math#cos>'(X, Y) :-
    (   nonvar(X),
        Y is cos(X),
        !
    ;   nonvar(Y),
        X is acos(Y)
    ).

'<http://www.w3.org/2000/10/swap/math#degrees>'(X, Y) :-
    (   nonvar(X),
        Y is X*180/pi,
        !
    ;   nonvar(Y),
        X is Y*pi/180
    ).

'<http://www.w3.org/2000/10/swap/math#difference>'([X, Y], Z) :-
    Z is X-Y.

'<http://www.w3.org/2000/10/swap/math#equalTo>'(X, Y) :-
    X =:= Y.

'<http://www.w3.org/2000/10/swap/math#exponentiation>'([X, Y], Z) :-
    (   nonvar(Y),
        Z is X**Y,
        !
    ;   nonvar(Z),
        Z =\= 0,
        X =\= 0,
        Y is log(Z)/log(X)
    ).

'<http://www.w3.org/2000/10/swap/math#floor>'(X, Y) :-
    Y is floor(X).

'<http://www.w3.org/2000/10/swap/math#greaterThan>'(X, Y) :-
     X > Y.

'<http://www.w3.org/2000/10/swap/math#integerQuotient>'([X, Y], Z) :-
    (   Y =\= 0
    ->  Z is round(floor(X/Y))
    ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#integerQuotient>'([X, Y], Z)))
    ).

'<http://www.w3.org/2000/10/swap/math#lessThan>'(X, Y) :-
    X < Y.

'<http://www.w3.org/2000/10/swap/math#logarithm>'([X, Y], Z) :-
    when(
        (   ground([X, Y])
        ;   ground([X, Z])
        ),
        (   getnumber(X, U),
            (   getnumber(Y, V),
                V =\= 0,
                U =\= 0,
                Z is log(U)/log(V),
                !
            ;   getnumber(Z, W),
                Y is U**(1/W)
            )
        )
    ).

'<http://www.w3.org/2000/10/swap/math#max>'(X, Y) :-
    list_min(X, Y).

'<http://www.w3.org/2000/10/swap/math#memberCount>'(X, Y) :-
    length(X, Y).

'<http://www.w3.org/2000/10/swap/math#min>'(X, Y) :-
    list_min(X, Y).

'<http://www.w3.org/2000/10/swap/math#negation>'(X, Y) :-
    (   nonvar(X)
    ->  Y is -X
    ;   (   nonvar(Y)
        ->  X is -Y
        )
    ).

'<http://www.w3.org/2000/10/swap/math#notEqualTo>'(X, Y) :-
    X =\= Y.

'<http://www.w3.org/2000/10/swap/math#notGreaterThan>'(X, Y) :-
    X =< Y.

'<http://www.w3.org/2000/10/swap/math#notLessThan>'(X, Y) :-
    X >= Y.

'<http://www.w3.org/2000/10/swap/math#product>'(X, Y) :-
    product(X, Y).

'<http://www.w3.org/2000/10/swap/math#quotient>'([X, Y], Z) :-
    (   Y =\= 0
    ->  Z is X/Y
    ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#quotient>'([X, Y], Z)))
    ).

'<http://www.w3.org/2000/10/swap/math#radians>'(X, Y) :-
    (   nonvar(X),
        Y is X*pi/180,
        !
    ;   nonvar(Y),
        X is Y*180/pi
    ).

'<http://www.w3.org/2000/10/swap/math#remainder>'([X, Y], Z) :-
    (   Y =\= 0
    ->  Z is X-Y*round(floor(X/Y))
    ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#remainder>'([X, Y], Z)))
    ).

'<http://www.w3.org/2000/10/swap/math#rounded>'(X, Y) :-
    Y is round(round(X)).

'<http://www.w3.org/2000/10/swap/math#roundedTo>'([X, Y], Z) :-
    F is 10**floor(Y),
    Z is round(round(X*F))/F.

'<http://www.w3.org/2000/10/swap/math#sin>'(X, Y) :-
    (   nonvar(X),
        Y is sin(X),
        !
    ;   nonvar(Y),
        X is asin(Y)
    ).

'<http://www.w3.org/2000/10/swap/math#sum>'(X, Y) :-
    sum(X, Y).

'<http://www.w3.org/2000/10/swap/math#tan>'(X, Y) :-
    (   nonvar(X),
        Y is tan(X),
        !
    ;   nonvar(Y),
        X is atan(Y)
    ).

%
% support
%
conj_list(true, []) :-
    !.
conj_list(A, [A]) :-
    A \= (_, _),
    A \= false,
    !.
conj_list((A, B), [A|C]) :-
    conj_list(B, C).

exopred(P, S, O) :-
    (   var(P),
        var(S),
        var(O)
    ->  pred(P),
        H =.. [P, S, O],
        clause(H, true)
    ;   (   var(P)
        ->  pred(P)
        ;   atom(P),
            current_predicate(P/2)
        ),
        call(P, S, O)
    ).

domain(A, true, B) :-
    !,
    findall('<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>'(C, _),
        (   member(C, A)
        ),
        D
    ),
    conj_list(B, D).
domain(_, B, B).

makevars(A, B, C) :-
    list_to_set(C, D),
    findvars(D, G),
    (   D \= G
    ->  throw(invalid_graffiti(D, in(A)))
    ;   true
    ),
    findall([X,_],
        (   member(X, D)
        ),
        F
    ),
    makevar(A, B, F).

makevar(A, B, D) :-
    atomic(A),
    !,
    (   atom(A),
        member([A,B], D)
    ->  true
    ;   B = A
    ).
makevar(A, A, _) :-
    var(A),
    !.
makevar([], [], _) :-
    !.
makevar([A|B], [C|D], F) :-
    makevar(A, C, F),
    makevar(B, D, F),
    !.
makevar(A, B, F) :-
    A =.. [Ch|Ct],
    (   sub_atom(Ch, 0, _, _, '_:')
    ->  C = [exopred, Ch|Ct]
    ;   C = [Ch|Ct]
    ),
    makevar(C, [Dh|Dt], F),
    nonvar(Dh),
    B =.. [Dh|Dt].

findvars(A, B) :-
    atomic(A),
    !,
    (   atom(A),
        sub_atom(A, 0, _, _, '_:')
    ->  B = [A]
    ;   B = []
    ).
findvars(A, []) :-
    var(A),
    !.
findvars([], []) :-
    !.
findvars([A|B], C) :-
    findvars(A, D),
    findvars(B, E),
    append(D, E, C),
    !.
findvars(A, B) :-
    A =.. C,
    findvars(C, B).

sum([], 0) :-
    !.
sum([A|B], C) :-
    sum(B, D),
    C is A+D.

product([], 1) :-
    !.
product([A|B], C) :-
    product(B, D),
    C is A*D.
