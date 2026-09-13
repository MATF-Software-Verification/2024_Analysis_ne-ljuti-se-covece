# Analiza projekta "Ne ljuti se čoveče"

GitHub repozitorijum posvećen izradi samostalnog praktičnog seminarskog rada za potrebe kursa **Verifikacija softvera** na master studijama Matematičkog fakulteta u Beogradu.

Praktični seminarski rad podrazumeva primenu alata i tehnika za statičku i dinamičku verifikaciju softvera nad izabranim studentskim projektom.

**Autor: Marija Božić 1044/2023**

## Opis analiziranog projekta

Analizirani projekat je implementacija igre **"Ne ljuti se čoveče"** razvijena u programskom jeziku C++ korišćenjem Qt framework-a.

Projekat sadrži:

1. zajedničke klase i poruke za komunikaciju,
2. serverski deo aplikacije,
3. klijentski deo igre,
4. testove implementirane korišćenjem Catch2 biblioteke.

Izvorni projekat:

[GitLab repozitorijum projekta](https://gitlab.com/matf-bg-ac-rs/course-rs/projects-2023-2024/ne-ljuti-se-covece/)

Analiza je izvršena nad granom:

```text
main
```

i commit-om:

```text
b50bedc6240d0f02dba7c2fed278bbcf3b80900d
```

Analizirani projekat je dodat u ovaj repozitorijum kao Git submodule.

## Korišćeni alati i tehnike

U okviru analize korišćeni su sledeći alati i tehnike:

1. **Valgrind Memcheck**  
   Dinamička analiza memorije i detekcija korišćenja neinicijalizovanih vrednosti i curenja memorije.

2. **Clang-Tidy**  
   Statička analiza izvornog C++ koda.

3. **Cppcheck**  
   Statička analiza sa fokusom na neinicijalizovane promenljive, upozorenja i potencijalne greške.

4. **AddressSanitizer**  
   Dinamička analiza memorijskih grešaka i curenja memorije.

5. **libFuzzer**  
   Coverage-guided fuzz testiranje funkcije `MessageFactory::createMessage()` pomoću velikog broja automatski generisanih ulaza.

6. **UndefinedBehaviorSanitizer**  
   Dinamička detekcija undefined behavior problema, uključujući korišćenje nevalidnih vrednosti enum tipa `Color`.

Dodatno su pokrenuti postojeći Catch2 testovi i izmerena je pokrivenost koda pomoću LCOV-a.

## Struktura repozitorijuma

```text
2024_Analysis_ne-ljuti-se-covece/
├── address_sanitizer/
├── clang_tidy/
├── cppcheck/
├── libfuzzer/
├── ne-ljuti-se-covece/
├── undefined_behavior_sanitizer/
├── unit_tests/
├── valgrind/
├── .gitmodules
├── ProjectAnalysisReport.md
└── README.md
```

Svaki direktorijum alata sadrži rezultate analize i, gde je potrebno, skriptu za reprodukciju rezultata.

## Pokretanje analiza

Svaki alat se može pokrenuti iz njegovog direktorijuma.

Na primer:

```bash
cd valgrind
./run_valgrind.sh
```

```bash
cd cppcheck
./run_cppcheck.sh
```

```bash
cd address_sanitizer
./run_asan.sh
```

```bash
cd libfuzzer
./run_libfuzzer.sh
```

```bash
cd undefined_behavior_sanitizer
./run_ubsan.sh
```

Postojeći testovi i LCOV analiza mogu se pokrenuti pomoću:

```bash
cd unit_tests
./run_tests.sh
```

Detaljna uputstva za svaki alat nalaze se u odgovarajućem `README.md` fajlu.

## Najvažniji rezultati

Analiza je pokazala nekoliko problema u projektu.

Posebno se izdvajaju:

- korišćenje neinicijalizovanog `TurnContext::currentPlayerColor`,
- neinicijalizovani članovi kao što su `CreateGameResponse::color` i `BaseParticipant::color`,
- mogući null pointer dereference u klijentskom kodu,
- potencijalni problemi sa upravljanjem memorijom,
- nevalidne vrednosti enum tipa `Color` detektovane pomoću UndefinedBehaviorSanitizer-a.

Više alata je nezavisno ukazalo na iste probleme, što povećava pouzdanost zaključaka.

Na primer, Cppcheck je statički detektovao neinicijalizovane `Color` članove, dok je UndefinedBehaviorSanitizer tokom izvršavanja pokazao da se ti članovi zaista mogu koristiti sa nevalidnim vrednostima.

Valgrind Memcheck je dodatno pokazao korišćenje neinicijalizovane vrednosti povezane sa `TurnContext::currentPlayerColor`.

libFuzzer je u završnom pokretanju izvršio 488435 generisanih ulaza nad `MessageFactory::createMessage()` bez pronađenog crash-a ili AddressSanitizer greške.

## Izveštaj

Detaljan opis korišćenih alata, rezultata i zaključaka nalazi se u:

[ProjectAnalysisReport.md](ProjectAnalysisReport.md)
