import { assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateCoachFoodBoundaries } from "./coach_food_safety.ts";

const question = [{ role: "user", content: "Suggest a dinner / اقترح عشاء" }];
const context = (allergens: string[] = [], extra: Record<string, unknown> = {}) =>
  ({ profile: { dietaryPreferences: { allergens, ...extra } } });
Deno.test("label inspection warnings are distinct from selecting the allergen later in the same sentence", () => {
  const restrictions = context(["peanut", "milk", "sesame"]);
  for (const text of [
    "Try chicken with rice. Check labels for peanuts, milk and sesame.",
    "Read the ingredient label for hidden milk before selecting the product.",
    "I suggest checking labels for peanuts and sesame.",
    "افحص ملصق المنتج بحثا عن الحليب والسمسم.",
    "اقرا المكونات لوجود الفول السوداني.",
  ]) validateCoachFoodBoundaries(text, question, restrictions);
  for (const text of [
    "Check labels and add peanuts.", "Read the ingredient label then use milk.",
    "Try checking labels before eating peanuts.", "Recommend milk but read labels first.",
    "افحص ملصق المنتج ثم اضف الحليب.", "اقرا المكونات ثم اشرب الحليب.",
    "راجع المكونات ثم كل الفول السوداني.",
  ]) assertThrows(() => validateCoachFoodBoundaries(text, question, restrictions));
});
Deno.test("English free-from warnings stay usable without hiding later or negated allergen use", () => {
  const restrictions = context(["peanut", "milk", "sesame"]);
  for (const prose of [
    "Choose a dinner free from peanuts, milk and sesame.",
    "Try rice with ingredients free from sesame and milk, without peanuts.",
  ]) validateCoachFoodBoundaries(prose, question, restrictions);
  for (const prose of [
    "Choose a dinner free from peanuts but add milk.",
    "Try a dinner not free from milk.",
    "Try a dinner not guaranteed to be free of peanuts.",
    "Try a dinner that is not milk-free.",
    "Choose a dinner free from milk but include sesame.",
  ]) assertThrows(() => validateCoachFoodBoundaries(prose, question, restrictions));
});
Deno.test("actual positive allergen suggestions are rejected in English and Arabic", () => {
  for (const [allergen, prose] of [
    ["peanut", "Try peanut butter on toast"], ["peanut", "اضف الفول السوداني للعشاء"],
    ["sesame", "Dinner: tahini with vegetables"], ["sesame", "اقترح سلطة مع الطحينة"],
    ["milk", "Have a glass of milk"], ["egg", "Add eggs"], ["fish", "Try salmon"],
    ["shellfish", "Include shrimp"], ["treeNut", "Try almonds"], ["wheat", "Use wheat flour"], ["soy", "Choose tofu"],
  ]) assertThrows(() => validateCoachFoodBoundaries(prose, question, context([allergen])), Error, "unsafe_dietary_advice");
});
Deno.test("negative warnings, observed facts and correctly qualified alternatives stay usable", () => {
  for (const prose of ["Avoid peanuts", "Choose peanut-free foods", "You have a peanut allergy", "You ate peanuts yesterday; avoid them now"])
    validateCoachFoodBoundaries(prose, question, context(["peanut"]));
  validateCoachFoodBoundaries("Try oat milk", question, context(["milk"]));
  validateCoachFoodBoundaries("اختر حليب الشوفان", question, context(["milk"]));
  assertThrows(() => validateCoachFoodBoundaries("Avoid milk but add peanuts", question, context(["milk", "peanut"])));
  assertThrows(() => validateCoachFoodBoundaries("Use oat milk and cow milk", question, context(["milk"])));
  assertThrows(() => validateCoachFoodBoundaries("Try almond milk", question, context(["milk", "treeNut"])));
});
Deno.test("declared culture, dietary pattern and explicit exclusions constrain suggestions without inventing requirements", () => {
  for (const [prose, extra] of [
    ["Try bacon", { requirements: ["halal"] }],
    ["Add wine", { requirements: ["halal"] }],
    ["Try shrimp", { requirements: ["kosher"] }],
    ["Try chicken", { pattern: "vegetarian" }],
    ["Try eggs", { pattern: "vegan" }],
    ["Try mushrooms", { excludedIngredients: ["mushrooms"] }],
    ["Try barley", { requirements: ["glutenFree"] }],
    ["Try milk", { requirements: ["lactoseFree"] }],
  ] as const) assertThrows(() => validateCoachFoodBoundaries(prose, question, context([], extra)));
  validateCoachFoodBoundaries("Try chicken", question, context([], { pattern: "omnivore" }));
  validateCoachFoodBoundaries("Try lactose-free milk", question, context([], { requirements: ["lactoseFree"] }));
  assertThrows(() => validateCoachFoodBoundaries("Try lactose-free milk", question, context(["milk"], { requirements: ["lactoseFree"] })));
  validateCoachFoodBoundaries("Try mushrooms", question, context());
  validateCoachFoodBoundaries("Peanut allergy symptoms require assessment", [{ role: "user", content: "What is a peanut allergy?" }], context(["peanut"]));
});

Deno.test("constraint wording does not hide a later actual unsafe recommendation", () => {
  for (const prose of ["Choose a dinner free of peanuts", "Given your peanut allergy, try rice with vegetables", "اختر عشاء خاليا من الفول السوداني"])
    validateCoachFoodBoundaries(prose, question, context(["peanut"]));
  assertThrows(() => validateCoachFoodBoundaries("Given your peanut allergy, try rice and add peanuts", question, context(["peanut"])));
  assertThrows(() => validateCoachFoodBoundaries("Choose a dinner free of milk but add peanuts", question, context(["milk", "peanut"])));
});

Deno.test("allergen lists label confirmed constraints without exempting later proposals", () => {
 const restrictions = context(["peanut", "milk", "sesame"]);
 for (const prose of [
   "Considering your peanut, milk, and sesame allergies, try rice with chicken.",
   "Given your allergies to peanuts, milk and sesame, try rice with chicken.",
   "Try a peanut-, milk-, and sesame-free dinner.",
   "مع حساسيتك تجاه الفول السوداني والحليب والسمسم، جرب الارز مع الدجاج.",
   "Avoiding peanuts, milk and sesame, choose chicken with rice.",
 ]) validateCoachFoodBoundaries(prose, question, restrictions);
 for (const prose of [
   "Given your allergies to peanuts, milk and sesame, try rice and add milk.",
   "مع حساسيتك تجاه الفول السوداني والحليب، جرب الارز واضف السمسم.",
   "Try peanuts even with your allergies.",
   "Dinner: chicken with rice and sesame.",
   "Given your milk allergy, dinner: milk with toast.",
   "Dinner with peanuts even with your allergies.",
 ]) assertThrows(() => validateCoachFoodBoundaries(prose, question, restrictions));
});

Deno.test("Arabic ingredient words do not match brown or white rice and unrelated words", () => {
 validateCoachFoodBoundaries("جرب الدجاج مع الارز البني", question, context(["milk"]));
 validateCoachFoodBoundaries("اختر الارز الابيض مع الخضار", question, context(["egg"]));
 validateCoachFoodBoundaries("يجوز اختيار وجبة مناسبة", question, context(["treeNut"]));
 validateCoachFoodBoundaries("اختر الحمية المناسبة وتناول العدس", question, context([], { pattern: "vegetarian" }));
 assertThrows(() => validateCoachFoodBoundaries("اضف اللبن الى الارز البني", question, context(["milk"])));
 assertThrows(() => validateCoachFoodBoundaries("اضف البيض الى الارز الابيض", question, context(["egg"])));
});

Deno.test("Arabic prepositions and conjunctions retain actual allergen detection and explicit negative warnings", () => {
 for (const text of ["جرب الارز بالحليب", "اضف الحليب والسمسم", "تناول حليبا مع العشاء", "جرب الدجاج بالسمسم"])
   assertThrows(() => validateCoachFoodBoundaries(text, question, context(["milk", "sesame"])));
 for (const text of ["اختر عشاء خاليا تماما من الحليب والسمسم", "جرب وجبة لا تحتوي على الحليب", "جرب الارز بلا حليب", "اختر وجبة تستبعد السمسم"])
   validateCoachFoodBoundaries(text, question, context(["milk", "sesame"]));
});
