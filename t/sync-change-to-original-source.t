use Prophet::Test::Syntax;

with 'Prophet::Test';

TODO: {
    todo_skip 'Update run_from_yaml', 1;
    Prophet::Test::Arena->run_from_yaml;
}

done_testing;

__DATA__
---
chickens:
  - ALICE
  - BOB
recipe:
  -
    - ALICE
    - create_record
    -
      props:
        - --B
        - charlie
      result: 10
  -
    - BOB
    - sync_from_peer
    -
      from: ALICE
  -
    - ALICE
    - sync_from_peer
    -
      from: BOB
