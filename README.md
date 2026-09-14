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
4. postojeći Catch2 test suite.

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

1. **Valgrind Memcheck** — dinamička analiza memorije i detekcija korišćenja neinicijalizovanih vrednosti i curenja memorije.
2. **Clang-Tidy** — statička analiza izvornog C++ koda.
3. **Cppcheck** — statička analiza sa fokusom na neinicijalizovane promenljive, upozorenja i potencijalne greške.
4. **AddressSanitizer** — dinamička analiza memorijskih grešaka i curenja memorije.
5. **libFuzzer** — coverage-guided fuzz testiranje funkcije `MessageFactory::createMessage()` pomoću automatski generisanih i mutiranih ulaza.
6. **UndefinedBehaviorSanitizer** — dinamička detekcija undefined behavior problema, uključujući korišćenje nevalidnih vrednosti enum tipa `Color`.

Postojeći Catch2 testovi iz analiziranog projekta korišćeni su kao izvršni scenario za pojedine dinamičke alate, ali se ne računaju kao posebna tehnika u ovom radu.

## Struktura repozitorijuma

```text
.
├── .github/
│   └── workflows/
│       ├── gate.yml
│       └── tickets.yml
├── address_sanitizer/
├── clang_tidy/
├── cppcheck/
├── libfuzzer/
├── ne-ljuti-se-covece/
├── undefined_behavior_sanitizer/
├── valgrind/
├── .gitignore
├── .gitmodules
├── README.md
└── ProjectAnalysisReport.md
```

Svaki direktorijum alata sadrži rezultate analize i skriptu za reprodukciju rezultata, zajedno sa dodatnom dokumentacijom i slikama gde je to primenljivo.

## Pokretanje analiza

```bash
cd valgrind && ./run_valgrind.sh
cd ../clang_tidy && ./run_clang_tidy.sh
cd ../cppcheck && ./run_cppcheck.sh
cd ../address_sanitizer && ./run_asan.sh
cd ../libfuzzer && ./run_libfuzzer.sh
cd ../undefined_behavior_sanitizer && ./run_ubsan.sh
```

Detaljna uputstva i rezultati nalaze se u `README.md` fajlu svakog pojedinačnog alata.

## Najvažniji rezultati

Analiza je pokazala više problema u projektu, među kojima se posebno izdvajaju:

- korišćenje neinicijalizovanog `TurnContext::currentPlayerColor`,
- neinicijalizovani članovi kao što su `CreateGameResponse::color` i `BaseParticipant::color`,
- mogući null pointer dereference u klijentskom kodu,
- potencijalni problemi sa upravljanjem memorijom,
- nevalidne vrednosti enum tipa `Color` detektovane pomoću UndefinedBehaviorSanitizer-a.

Više alata je nezavisno ukazalo na iste probleme. Na primer, Cppcheck je statički detektovao neinicijalizovane `Color` članove, dok je UndefinedBehaviorSanitizer tokom izvršavanja pokazao da se ti članovi mogu koristiti sa nevalidnim vrednostima.

Valgrind Memcheck je dodatno pokazao korišćenje neinicijalizovane vrednosti u logici povezanoj sa `TurnContext::currentPlayerColor`.

libFuzzer je u završnom pokretanju izvršio 488435 ulaza nad `MessageFactory::createMessage()` bez pronađenog crash-a ili AddressSanitizer greške.

## Izveštaj

Detaljan opis korišćenih alata, rezultata i zaključaka nalazi se u:

[ProjectAnalysisReport.md](ProjectAnalysisReport.md)
