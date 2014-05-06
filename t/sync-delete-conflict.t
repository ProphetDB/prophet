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
  - DEC
  - KAGENEKO
recipe:
  -
    - DEC
    - create_record
    - props:
        - --Sauron
        - eee_yow
        - --He
        - crunch
        - --the_Shadow
        - kayo
        - --the_Enemy
        - aiieee
        - --the_Lord_of_the_Rings
        - thwacke
      result: 4
  -
    - KAGENEKO
    - sync_from_peer
    - from: DEC
  -
    - DEC
    - update_record
    - props:
        He: aiieee
        the_Enemy: kayo
        the_Shadow: eee_yow
      record: 4
  -
    - KAGENEKO
    - delete_record
    - record: 4
  -
    - KAGENEKO
    - sync_from_peer
    - from: DEC
