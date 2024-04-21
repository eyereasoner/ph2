% ------------------------------------------
% retina -- Jos De Roo, Patrick Hochstenbach
% ------------------------------------------
%
% See https://github.com/KNowledgeOnWebScale/retina
%

:- use_module(library(between)).
:- use_module(library(format)).
:- use_module(library(iso_ext)).
:- use_module(library(lists)).
:- use_module(library(random)).
:- use_module(library(si)).
:- use_module(library(terms)).
:- use_module(library(uuid)).

:- dynamic(answer/1).
:- dynamic(brake/0).
:- dynamic(implies/2).
:- dynamic(label/1).
:- dynamic(recursion/1).
:- dynamic(skolem/2).
:- dynamic(uuid/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#nand>'/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#nano>'/2).
:- dynamic('<http://www.w3.org/2000/10/swap/log#nans>'/2).

version_info('retina v5.4.0 (2024-04-21)').

% run
run :-
    bb_put(limit, -1),
    bb_put(fm, 0),
    uuidv4_string(Genid),
    bb_put(genid, Genid),
    relabel_graffiti,
    catch(forward(0), Exc,
        (   writeq(Exc),
            write('.'),
            nl,
            (   Exc = inference_fuse(_,_)
            ->  halt(2)
            ;   halt(1)
            )
        )
    ),
    bb_get(fm, Cnt),
    (   Cnt = 0
    ->  true
    ;   format(user_error, "*** fm=~w~n", [Cnt]),
        flush_output(user_error)
    ),
    (   '<http://www.w3.org/2000/10/swap/log#nand>'(_, _)
    ->  true
    ;   version_info(Version),
        format("% ~w~n", [Version])
    ),
    halt(0).

% relabel_graffiti
%   Replace all graffiti in negative surfaces with a new generated variables.
%   E.g. (_:A) log:nand { .. _:A .. }
%   becomes
%   (_A_1) log:nand { .. _A_1 .. }
relabel_graffiti :-
    P = '<http://www.w3.org/2000/10/swap/log#nand>',
    A =.. [P, _, _],
    retract(A),
    tr_tr(A, B),
    assertz(B),
    false.
relabel_graffiti.

tr_tr([], []) :-
    !.
tr_tr([A|B], [C|D]) :-
    !,
    tr_tr(A, C),
    tr_tr(B, D).
tr_tr(A, A) :-
    number(A),
    !.
tr_tr(A, B) :-
    A =.. [C|D],
    tr_tr(D, E),
    (   C = '<http://www.w3.org/2000/10/swap/log#nand>',
        E = [[_|_]|_]
    ->  tr_graffiti(A, B)
    ;   B =.. [C|E]
    ).

tr_graffiti(A, B) :-
    A =.. [C, D, E],
    tr_tr(D, T),
    tr_tr(E, R),
    findall([G, H],
        (   member(G, T),
            genlabel(G, H)
        ),
        L
    ),
    couple(_, M, L),
    makevar(R, O, L),
    B =.. [C, M, O].

% forward(+Recursion)
%   Forward chaining starting with Recursion step 0 until Recursion
%   larger than bb_get(limit,Value) (default: Value = -1)
forward(Recursion) :-
    (   % find all implies rules
        implies(Prem, Conc),
        % match the premise Prem against the database
        Prem,
        % check if the conclusion Conc is not already defined
        (   Conc = ':-'(C, P)
        ->  \+clause(C, P)
        ;   \+Conc
        ),
        % create witnesses if needed
        (   Conc \= implies(_, _),
            Conc \= ':-'(_, _)
        ->  labelvars(Conc)
        ;   true
        ),
        % assert the conclusion
        astep(Conc),
        % release the brake
        retract(brake),
        % repeat the process
        false
    ;   brake,
        (   R is Recursion+1,
            (   \+recursion(R)
            ->  assertz(recursion(R))
            ;   true
            ),
            bb_get(limit, Limit),
            Recursion < Limit,
            forward(R)
        ;   true
        ),
        !
    ;   assertz(brake),
        forward(Recursion)
    ).

% labelvars(+Term)
%   Create witnesses for a free variables in Term
labelvars(Term) :-
    (   retract(label(Current))
    ->  true
    ;   Current = 0
    ),
    numbervars(Term, Current, Next),
    assertz(label(Next)).

% astep(+Term)
%   Assert +Term or write to the stdout if the Term = answer(Answer)
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
        (   A = answer(Answer)
        ->  wt(Answer)
        ;   true
        )
    ;   true
    ).

% wt(+Term)
%   write term
wt(exopred(A, B, C)) :-
    !,
    D =.. [A, B, C],
    wt(D).
wt((A, B)) :-
    !,
    wt(A),
    wt(B).
wt(A) :-
    writeq(A),
    write('.'),
    nl.

% check recursion
within_recursion(R) :-
    (   var(R)
    ->  R = 1
    ;   true
    ),
    (   R = 0
    ->  brake
    ;   bb_get(limit, L),
        (   L < R
        ->  bb_put(limit, R)
        ;   true
        ),
        recursion(R)
    ).

%%%
% rules
%

% implies(+Premise,-Conclusion)
%   From Premise follows the Conclusion.

% - blow inference fuse (negative surface)
%   Given:
%       (Graffiti) log:nand {
%            TripleX
%       }.
%   If TripleX is true, we can throw an inference fuse
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        makevars(G, H, V),
        % test if the predicate is true (exists in the database)
        catch(call(H), _, false),
        % creating fuse explanation
        (   H = '<http://www.w3.org/2000/10/swap/log#nand>'(_, C)
        ->  I = '<http://www.w3.org/2000/10/swap/log#nand>'(_, C)
        ;   I = H
        ),
        '<http://www.w3.org/2000/10/swap/log#nand>'(_, I)
        ), throw(inference_fuse('<http://www.w3.org/2000/10/swap/log#nand>'(V, G), H))).

% - blow inference fuse (negative triple)
%   Given:
%       () log:nano {
%           TripleX
%       }..
%   If TripleX is true, we can throw an inference fuse
implies(('<http://www.w3.org/2000/10/swap/log#nano>'(A, T),
        % test if the predicate is true (exists in the database)
        catch(call(T), _, false)
        ), throw(inference_fuse('<http://www.w3.org/2000/10/swap/log#nano>'(A, T), T))).

% - simplify graffiti
%   Remove unused graffiti nodes.
%   Given:
%      (_:A _:B) log:nand {
%          _:A a :X .
%      }
%   create a
%      (_:A) log:nand {
%          _:A a :X .
%      }
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        findvars(G, U),
        findall(M,
            (   member(M, V),
                memberchk(M, U)
            ),
            W
        ),
        W \= V
        ), '<http://www.w3.org/2000/10/swap/log#nand>'(W, G)).

% - simplify negative surfaces
%   Given:
%      (Graffiti) log:nand {
%          TripleX
%          () log:nand {
%               () log:nand {
%                  TripleY
%               }
%          }
%      }
%    becomes
%      (Graffiti) log:nand {
%          TripleX
%          TripleY
%      }
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        select('<http://www.w3.org/2000/10/swap/log#nand>'(Z, H), B, K),
        conj_list(H, M),
        list_to_set(M, T),
        select('<http://www.w3.org/2000/10/swap/log#nand>'(W, O), T, N),
        list_si(W),
        (   conj_list(O, D),
            append(K, D, E),
            conj_list(C, E)
        ;   length(K, I),
            I > 1,
            conj_list(F, N),
            conj_list(C, ['<http://www.w3.org/2000/10/swap/log#nand>'([], F)|K])
        ),
        append([V, Z, W], U)
        ), '<http://www.w3.org/2000/10/swap/log#nand>'(U, C)).

% - resolve negative surfaces
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        \+member('<http://www.w3.org/2000/10/swap/log#nano>'(_, _), B),
        \+member('<http://www.w3.org/2000/10/swap/log#nans>'(_, _), B),
        findall(1,
            (   member('<http://www.w3.org/2000/10/swap/log#nand>'(_, _), B)
            ),
            O
        ),
        length(O, E),
        length(B, D),
        memberchk(E, [0, 2, D]),
        '<http://www.w3.org/2000/10/swap/log#nand>'(W, F),
        list_si(W),
        conj_list(F, K),
        list_to_set(K, N),
        \+member('<http://www.w3.org/2000/10/swap/log#nano>'(_, _), N),
        \+member('<http://www.w3.org/2000/10/swap/log#nans>'(_, _), N),
        length(N, 2),
        makevars(N, J, W),
        select('<http://www.w3.org/2000/10/swap/log#nand>'(U, C), J, [P]),
        list_si(U),
        (   select('<http://www.w3.org/2000/10/swap/log#nand>'(Z, Q), B, A),
            list_si(Z),
            M = ['<http://www.w3.org/2000/10/swap/log#nand>'(U, C)|A],
            conj_list(Q, R),
            memberchk(P, R)
        ;   select(Q, B, A),
            M = [P|A],
            conj_list(C, R),
            memberchk(Q, R)
        ),
        list_to_set(M, T),
        conj_list(H, T),
        ground('<http://www.w3.org/2000/10/swap/log#nand>'(V, H))
        ), '<http://www.w3.org/2000/10/swap/log#nand>'(V, H)).

% - create forward rule
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        \+member('<http://www.w3.org/2000/10/swap/log#nano>'(_, _), B),
        \+member('<http://www.w3.org/2000/10/swap/log#nans>'(_, _), B),
        select('<http://www.w3.org/2000/10/swap/log#nand>'(Z, H), B, K),
        list_si(Z),
        conj_list(R, K),
        find_graffiti(K, D),
        append(V, D, U),
        makevars([R, H], [Q, S], U),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, I)).

% - create contrapositive rule
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        \+member('<http://www.w3.org/2000/10/swap/log#nand>'(_, _), B),
        \+member('<http://www.w3.org/2000/10/swap/log#nano>'(_, _), B),
        \+member('<http://www.w3.org/2000/10/swap/log#nans>'(_, _), B),
        \+member(exopred(_, _, _), B),
        (   length(B, O),
            O =< 2
        ->  select(R, B, J)
        ;   B = [R|J]
        ),
        conj_list(T, J),
        findvars(R, N),
        findall(A,
            (   member(A, V),
                \+member(A, N)
            ),
            Z
        ),
        E = '<http://www.w3.org/2000/10/swap/log#nand>'(Z, T),
        find_graffiti([R], D),
        append(V, D, U),
        makevars([R, E], [Q, S], U),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, I)).

% - create backward rule
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        select('<http://www.w3.org/2000/10/swap/log#nano>'(Z, T), B, K),
        list_si(Z),
        conj_list(R, K),
        conjify(R, S),
        find_graffiti([R], D),
        append(V, D, U),
        makevars(':-'(T, S), C, U)
        ), C).

% - convert universal statements
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        V \= [],
        conj_list(G, [G]),
        (   G = '<http://www.w3.org/2000/10/swap/log#nand>'(Z, H)
        ->  true
        ;   Z = [],
            H = '<http://www.w3.org/2000/10/swap/log#nand>'([], G)
        ),
        list_si(Z),
        conj_list(H, B),
        member(M, B),
        findall('<http://www.w3.org/2000/10/swap/log#skolem>'(V, X),
            (   member(X, Z)
            ),
            Y
        ),
        conj_list(S, Y),
        append(V, Z, U),
        makevars(':-'(M, S), C, U)
        ), C).

% - create question
implies(('<http://www.w3.org/2000/10/swap/log#nand>'(V, G),
        list_si(V),
        conj_list(G, L),
        list_to_set(L, B),
        select('<http://www.w3.org/2000/10/swap/log#nans>'(Z, H), B, K),
        list_si(Z),
        conj_list(P, K),
        find_graffiti(K, D),
        append(V, D, U),
        makevars([P, H], [Q, S], U),
        findvars(S, W),
        makevars(S, I, W)
        ), implies(Q, answer(I))).

%%%
% built-ins
%

% graph
'<http://www.w3.org/2000/10/swap/graph#list>'(A, B) :-
    conj_list(A, B).

% list
'<http://www.w3.org/2000/10/swap/list#append>'(A, B) :-
    nonvar(A),
    append(A, B).

'<http://www.w3.org/2000/10/swap/list#first>'(A, B) :-
    nonvar(A),
    A = [B|_].

'<http://www.w3.org/2000/10/swap/list#firstRest>'([A|B], [A, B]).

'<http://www.w3.org/2000/10/swap/list#in>'(A, B) :-
    nonvar(B),
    member(A, B).

'<http://www.w3.org/2000/10/swap/list#iterate>'(A, [B, C]) :-
    nonvar(A),
    nth0(B, A, C).

'<http://www.w3.org/2000/10/swap/list#last>'(A, B) :-
    nonvar(A),
    append(_, [B], A).

'<http://www.w3.org/2000/10/swap/list#length>'(A, B) :-
    nonvar(A),
    length(A, B).

'<http://www.w3.org/2000/10/swap/list#map>'([A, B], C) :-
    nonvar(A),
    nonvar(B),
    findall(E,
        (   member(F, A),
            G =.. [B, F, E],
            G
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#member>'(A, B) :-
    nonvar(A),
    member(B, A).

'<http://www.w3.org/2000/10/swap/list#memberAt>'([A, B], C) :-
    nonvar(A),
    nth0(B, A, C).

'<http://www.w3.org/2000/10/swap/list#remove>'([A, B], C) :-
    nonvar(A),
    nonvar(B),
    findall(I,
        (   member(I, A),
            I \= B
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#removeAt>'([A, B], C) :-
    nonvar(A),
    nth0(B, A, D),
    findall(I,
        (   member(I, A),
            I \= D
        ),
        C
    ).

'<http://www.w3.org/2000/10/swap/list#removeDuplicates>'(A, B) :-
    nonvar(A),
    list_to_set(A, B).

'<http://www.w3.org/2000/10/swap/list#rest>'(A, B) :-
    nonvar(A),
    A = [_|B].

'<http://www.w3.org/2000/10/swap/list#sort>'(A, B) :-
    nonvar(A),
    sort(A, B).

%log
'<http://www.w3.org/2000/10/swap/log#bound>'(X, Y) :-
    (   nonvar(X)
    ->  Y = true
    ;   Y = false
    ).

'<http://www.w3.org/2000/10/swap/log#call>'(A, B) :-
    call(A),
    catch(call(B), _, false).

'<http://www.w3.org/2000/10/swap/log#callWithCleanup>'(A, B) :-
    call_cleanup(A, B).

'<http://www.w3.org/2000/10/swap/log#callWithOptional>'(A, B) :-
    call(A),
    (   \+catch(call(B), _, false)
    ->  true
    ;   catch(call(B), _, false)
    ).

'<http://www.w3.org/2000/10/swap/log#collectAllIn>'([A, B, C], D) :-
    within_recursion(D),
    nonvar(B),
    catch(findall(A, B, E), _, E = []),
    E = C.

'<http://www.w3.org/2000/10/swap/log#equalTo>'(X, Y) :-
    X = Y.

'<http://www.w3.org/2000/10/swap/log#forAllIn>'([A, B], C) :-
    within_recursion(C),
    nonvar(A),
    nonvar(B),
    forall(A, B).

'<http://www.w3.org/2000/10/swap/log#graffiti>'(A, B) :-
    nonvar(A),
    term_variables(A, B).

'<http://www.w3.org/2000/10/swap/log#ifThenElseIn>'([A, B, C], D) :-
    within_recursion(D),
    nonvar(A),
    nonvar(B),
    nonvar(C),
    if_then_else(A, B, C).

'<http://www.w3.org/2000/10/swap/log#notEqualTo>'(X, Y) :-
    X \= Y.

'<http://www.w3.org/2000/10/swap/log#rawType>'(A, B) :-
    raw_type(A, C),
    C = B.

'<http://www.w3.org/2000/10/swap/log#repeat>'(A, B) :-
    nonvar(A),
    C is A-1,
    between(0, C, B).

'<http://www.w3.org/2000/10/swap/log#skolem>'(A, B) :-
    (   ground(A)
    ;   nonvar(B)
    ),
    (   skolem(A, B)
    ->  true
    ;   var(B),
        bb_get(genid, C),
        genlabel('#t', D),
        atom_chars(D, E),
        append(["<http://knowledgeonwebscale.github.io/.well-known/genid/", C, E, ">"], F),
        atom_chars(B, F),
        assertz(skolem(A, B))
    ).

'<http://www.w3.org/2000/10/swap/log#uri>'(X, Y) :-
    (   nonvar(X),
        atom_concat('<', U, X),
        atom_concat(V, '>', U),
        atom_chars(V, Y),
        !
    ;   nonvar(Y),
        atom_chars(U, Y),
        atom_concat('<', U, V),
        atom_concat(V, '>', X)
    ).

'<http://www.w3.org/2000/10/swap/log#uuid>'(X, Y) :-
    ground(X),
    '<http://www.w3.org/2000/10/swap/log#uri>'(X, U),
    (   uuid(U, Y)
    ->  true
    ;   uuidv4_string(Y),
        assertz(uuid(U, Y))
    ).

% math
'<http://www.w3.org/2000/10/swap/math#absoluteValue>'(X, Y) :-
    nonvar(X),
    getnumber(X, U),
    Y is abs(U).

'<http://www.w3.org/2000/10/swap/math#acos>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is acos(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is cos(V)
    ).

'<http://www.w3.org/2000/10/swap/math#asin>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is asin(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is sin(V)
    ).

'<http://www.w3.org/2000/10/swap/math#atan>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is atan(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is tan(V)
    ).

'<http://www.w3.org/2000/10/swap/math#atan2>'([X, Y], Z) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    Z is atan(U/V).

'<http://www.w3.org/2000/10/swap/math#ceiling>'(X, Y) :-
    nonvar(X),
    getnumber(X, U),
    Y is ceiling(U).

'<http://www.w3.org/2000/10/swap/math#cos>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is cos(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is acos(V)
    ).

'<http://www.w3.org/2000/10/swap/math#degrees>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is U*180/pi,
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is V*pi/180
    ).

'<http://www.w3.org/2000/10/swap/math#difference>'([X, Y], Z) :-
    (   nonvar(X),
        nonvar(Y),
        getnumber(X, U),
        getnumber(Y, V),
        Z is U-V,
        !
    ;   nonvar(X),
        nonvar(Z),
        getnumber(X, U),
        getnumber(Z, W),
        Y is U-W,
        !
    ;   nonvar(Y),
        nonvar(Z),
        getnumber(Y, V),
        getnumber(Z, W),
        X is V+W
    ).

'<http://www.w3.org/2000/10/swap/math#equalTo>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U =:= V.

'<http://www.w3.org/2000/10/swap/math#exponentiation>'([X, Y], Z) :-
    nonvar(X),
    getnumber(X, U),
    (   nonvar(Y),
        getnumber(Y, V),
        Z is U**V,
        !
    ;   nonvar(Z),
        getnumber(Z, W),
        W =\= 0,
        U =\= 0,
        Y is log(W)/log(U)
    ).

'<http://www.w3.org/2000/10/swap/math#floor>'(X, Y) :-
    nonvar(X),
    getnumber(X, U),
    Y is floor(U).

'<http://www.w3.org/2000/10/swap/math#greaterThan>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U > V.

'<http://www.w3.org/2000/10/swap/math#integerQuotient>'([X, Y], Z) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    (   V =\= 0
    ->  Z is round(floor(U/V))
    ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#integerQuotient>'([X, Y], Z)))
    ).

'<http://www.w3.org/2000/10/swap/math#lessThan>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U < V.

'<http://www.w3.org/2000/10/swap/math#logarithm>'([X, Y], Z) :-
    nonvar(X),
    getnumber(X, U),
    (   nonvar(Y),
        getnumber(Y, V),
        U =\= 0,
        V =\= 0,
        Z is log(U)/log(V),
        !
    ;   nonvar(Z),
        getnumber(Z, W),
        Y is U**(1/W)
    ).

'<http://www.w3.org/2000/10/swap/math#max>'(X, Y) :-
    ground(X),
    list_max(X, Y).

'<http://www.w3.org/2000/10/swap/math#memberCount>'(X, Y) :-
    nonvar(X),
    length(X, Y).

'<http://www.w3.org/2000/10/swap/math#min>'(X, Y) :-
    ground(X),
    list_min(X, Y).

'<http://www.w3.org/2000/10/swap/math#negation>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U)
    ->  Y is -U
    ;   (   nonvar(Y),
            getnumber(Y, V)
        ->  X is -V
        )
    ).

'<http://www.w3.org/2000/10/swap/math#notEqualTo>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U =\= V.

'<http://www.w3.org/2000/10/swap/math#notGreaterThan>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U =< V.

'<http://www.w3.org/2000/10/swap/math#notLessThan>'(X, Y) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    U >= V.

'<http://www.w3.org/2000/10/swap/math#product>'(X, Y) :-
    ground(X),
    product(X, Y).

'<http://www.w3.org/2000/10/swap/math#quotient>'([X, Y], Z) :-
    (   nonvar(X),
        nonvar(Y),
        getnumber(X, U),
        getnumber(Y, V),
        (   V =\= 0
        ->  Z is U/V
        ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#quotient>'([X, Y], Z)))
        ),
        !
    ;   nonvar(X),
        nonvar(Z),
        getnumber(X, U),
        getnumber(Z, W),
        (   W =\= 0
        ->  Y is U/W
        ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#quotient>'([X, Y], Z)))
        ),
        !
    ;   nonvar(Y),
        nonvar(Z),
        getnumber(Y, V),
        getnumber(Z, W),
        X is V*W
    ).

'<http://www.w3.org/2000/10/swap/math#radians>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is U*pi/180,
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is V*180/pi
    ).

'<http://www.w3.org/2000/10/swap/math#remainder>'([X, Y], Z) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    (   V =\= 0
    ->  Z is U-V*floor(U/V)
    ;   throw(zero_division('<http://www.w3.org/2000/10/swap/math#remainder>'([X, Y], Z)))
    ).

'<http://www.w3.org/2000/10/swap/math#rounded>'(X, Y) :-
    nonvar(X),
    getnumber(X, U),
    Y is round(round(U)).

'<http://www.w3.org/2000/10/swap/math#roundedTo>'([X, Y], Z) :-
    nonvar(X),
    nonvar(Y),
    getnumber(X, U),
    getnumber(Y, V),
    F is 10**floor(V),
    Z is round(round(U*F))/F.

'<http://www.w3.org/2000/10/swap/math#sin>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is sin(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is asin(V)
    ).

'<http://www.w3.org/2000/10/swap/math#sum>'(X, Y) :-
    ground(X),
    sum(X, Y).

'<http://www.w3.org/2000/10/swap/math#tan>'(X, Y) :-
    (   nonvar(X),
        getnumber(X, U),
        Y is tan(U),
        !
    ;   nonvar(Y),
        getnumber(Y, V),
        X is atan(V)
    ).

%
% support
%

% conj_list(?Conjunction,?List).
%   True if ?List contains all items of the ?Conjunction
%   E.g. conj_list((1,2,3),[1,2,3])
conj_list(true, []) :-
    !.
conj_list(A, [A]) :-
    A \= (_, _),
    A \= false,
    !.
conj_list((A, B), [A|C]) :-
    conj_list(B, C).

% exopred(?Predicate,?Subject,?Object)
%    True when an ?Predicate exists that matches ?Preficate(?Subject,?Object)
%    E.g. exopred(X,'<http://example.org/ns#Alice>', '<http://example.org/ns#Person>').
exopred(P, S, O) :-
    (   var(P)
    ->  current_predicate(P/2),
        sub_atom(P, 0, 1, _, '<'),
        sub_atom(P, _, 1, 0, '>'),
        \+sub_atom(P, 0, 32, _, '<http://www.w3.org/2000/10/swap/')
    ;   true
    ),
    call(P, S, O).

conjify((A, B), (C, D)) :-
    !,
    conjify(A, C),
    conjify(B, D).
conjify('<http://www.w3.org/2000/10/swap/log#callWithCut>'(A, _), (A, !)) :-
    !.
conjify(A, A).

% makevars(+List,-NewList,?Graffiti)
%   Transform a pso-predicate list into a new pso-predicate list with
%   all graffiti filled in. Possible graffiti in the
%   predicate position will be replaced by an exopred.
%   E.g.
%      makevars( '<urn:example.org:is>'('_:A',42), Y , ['_:A'] ).
%      Y = '<urn:example.org:is>'(_A,42)
%      makevars( '_:B'('_:A',42), Y , ['_:A','_:B'] ).
%      Y = 'exopred(_A,42,_B)'
makevars(A, B, C) :-
    list_to_set(C, D),
    findvars(D, G),
    (   D \= G
    ->  throw(invalid_graffiti(D, in(A)))
    ;   true
    ),
    findall([X, _],
        (   member(X, D)
        ),
        F
    ),
    makevar(A, B, F).

makevar(A, B, D) :-
    atomic(A),
    !,
    (   atom(A),
        member([A, B], D)
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
    (   sub_atom(Ch, 0, 2, _, '_:')
    ->  C = [exopred, Ch|Ct]
    ;   C = [Ch|Ct]
    ),
    makevar(C, [Dh|Dt], F),
    nonvar(Dh),
    B =.. [Dh|Dt].

% findvars(+Predicate,-VarList)
%   Find all blank node reference in a pso predicate expression.
%   E.g. findvars('<urn:foo>'('_:A','_:B'),X)
%        X = ['_:A','_:B']
findvars(A, B) :-
    atomic(A),
    !,
    (   atom(A),
        sub_atom(A, 0, 2, _, '_:')
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

% find_graffiti(+Predicate,-GraffitiList)
%   Find all graffiti declaration in a (nested) surface.
%   E.g. find_graffiti('<http://www.w3.org/2000/10/swap/log#nand>'(['_:A'],'<urn:foo>'('_:C',2)),X).
%        X = ['_:A'].
find_graffiti(A, []) :-
    atomic(A),
    !.
find_graffiti([], []) :-
    !.
find_graffiti([A|B], C) :-
    !,
    find_graffiti(A, D),
    find_graffiti(B, E),
    append(D, E, C).
find_graffiti(A, B) :-
    A =.. [C, D, E],
    C = '<http://www.w3.org/2000/10/swap/log#nand>',
    list_si(D),
    !,
    find_graffiti(E, F),
    append(D, F, B).
find_graffiti(A, B) :-
    A =.. C,
    find_graffiti(C, B).

% sum(+ListOfNumbers,-SumOfNumbers)
%   True when the sum of ListOfNumbers is SumOfNumbers.
%   E.g. sum([1,2],3).
sum([], 0) :-
    !.
sum([A|B], C) :-
    getnumber(A, D),
    sum(B, E),
    C is D+E.

% product(+ListOfNumbers,-ProductOfNumbers)
%   True when the product of ListOfNumbers is ProductOfNumbers.
%   E.g. product([2,4],8).
product([], 1) :-
    !.
product([A|B], C) :-
    getnumber(A, D),
    product(B, E),
    C is D*E.

% includes(?ListA,?ListB)
%   True when every item of ListB is in ListA
%   E.g. includes([1,2,[5]],[[5],2]).
includes(_, []) :-
    !.
includes(X, [Y|Z]) :-
    member(Y, X),
    includes(X, Z).

% couple(?List1, ?List2, ?CoupleList)
%  True if CoupleList is a pair wise combination of elements
%  of List1 and List2.
%  Example: couple([1,2,3],['A','B','C'],[[1,'A'],[2,'B'],[3,'C'])
couple([], [], []).
couple([A|B], [C|D], [[A, C]|E]) :-
    couple(B, D, E).

% genlabel(+OldAtom,-NewAtom)
%  For each invocation of this built-in a new label will
%  be created for OldAtom by appending it with an ever
%  increasing '_<Number>'
%  Example: genlabel('A','A_1'),genlabel('A','A_2'),...
genlabel(A, B) :-
    (   bb_get(A, C)
    ->  D is C+1,
        bb_put(A, D),
        taglabel(A, D, B)
    ;   bb_put(A, 1),
        taglabel(A, 1, B)
    ).

% taglabel(+Atom,+Number,-Tag)
%   Tag is the result of appending '_<Number>' to '<Atom>'
%   Example: taglabel('A',1,'A_1')
taglabel(A, B, C) :-
    atom_chars(A, D),
    number_chars(B, E),
    append([D, "_", E], F),
    atom_chars(C, F).

% raw_type(+Term,-Type)
raw_type(A, '<http://www.w3.org/1999/02/22-rdf-syntax-ns#List>') :-
    list_si(A),
    !.
raw_type(A, '<http://www.w3.org/2000/10/swap/log#Literal>') :-
    number(A),
    !.
raw_type(true, '<http://www.w3.org/2000/10/swap/log#Formula>').
raw_type(false, '<http://www.w3.org/2000/10/swap/log#Formula>').
raw_type(A, '<http://www.w3.org/2000/10/swap/log#Literal>') :-
    atom(A),
    \+ sub_atom(A, 0, 2, _, '_:'),
    \+ (sub_atom(A, 0, 1, _, '<'), sub_atom(A, _, 1, 0, '>')),
    !.
raw_type(literal(_, _), '<http://www.w3.org/2000/10/swap/log#Literal>') :-
    !.
raw_type((_, _), '<http://www.w3.org/2000/10/swap/log#Formula>') :-
    !.
raw_type(A, '<http://www.w3.org/2000/10/swap/log#Formula>') :-
    functor(A, B, C),
    dif_si(B, :),
    C >= 2,
    !.
raw_type(A, '<http://www.w3.org/2000/10/swap/log#LabeledBlankNode>') :-
    sub_atom(A, _, 2, _, '_:'),
    !.
raw_type(A, '<http://www.w3.org/2000/10/swap/log#SkolemIRI>') :-
    sub_atom(A, _, 19, _, '/.well-known/genid/'),
    !.
raw_type(_, '<http://www.w3.org/2000/10/swap/log#Other>').

% getnumber(+Literal,-Number)
getnumber(A, A) :-
    number(A),
    !.
getnumber(literal(A, _), B) :-
    ground(A),
    atom_chars(A, C),
    catch(number_chars(B, C), _, fail).

%%%
% debugging tools
%

fm(A) :-
    (   A = !
    ->  true
    ;   format(user_error, "*** ~q~n", [A]),
        flush_output(user_error)
    ),
    bb_get(fm, B),
    C is B+1,
    bb_put(fm, C).

mf(A) :-
    forall(
        catch(A, _, false),
        format(user_error, "*** ~q~n", [A])
    ),
    flush_output(user_error).
